// scheduler.ts — the wedge, as a pure function.
//
// Given each member's busy intervals and a plain-language-derived constraint set
// ("a weekend afternoon, 3h, at least 5 of 6 free"), return the candidate slots
// ranked by how many members are available. No DB, no I/O — trivially testable.
//
// All instants are epoch milliseconds in UTC. Day-of-week and time-of-day are
// evaluated in `timezone`, because "weekend afternoon" is inherently local.

export interface BusyInterval {
  start: number; // epoch ms, UTC
  end: number;   // epoch ms, UTC
}

export interface Member {
  userId: string;
  busy: BusyInterval[];
}

export interface Constraints {
  windowStart: number;       // epoch ms, inclusive — earliest a slot may start
  windowEnd: number;         // epoch ms, exclusive — latest a slot may end
  allowedWeekdays: number[]; // 0=Sun … 6=Sat, evaluated in `timezone`
  dayStartMinutes: number;   // local minutes from midnight (e.g. 12:00 -> 720)
  dayEndMinutes: number;     // local minutes from midnight (e.g. 17:00 -> 1020)
  durationMinutes: number;   // required slot length
  stepMinutes: number;       // candidate granularity (e.g. 30)
  timezone: string;          // IANA tz (e.g. "America/Los_Angeles")
  quorum?: number;           // min available members; defaults to "everyone"
}

export interface Slot {
  start: number;
  end: number;
  availableUserIds: string[];
  score: number; // === availableUserIds.length
}

export interface SlotSearch {
  slots: Slot[];
  /** True when every returned slot works for the whole group. */
  everyoneFree: boolean;
  /** Members considered — the denominator behind each slot's score. */
  memberCount: number;
  /** Availability floor the returned slots met. */
  quorum: number;
}

const MINUTE = 60_000;

/** More than half the group, rounded up — the fallback when nobody's all free. */
export function majorityOf(memberCount: number): number {
  return Math.max(1, Math.ceil(memberCount / 2));
}

// One formatter per timezone: constructing an Intl.DateTimeFormat costs far more
// than using it, and a six-month window asks for thousands of conversions.
const formatters = new Map<string, Intl.DateTimeFormat>();
function formatterFor(timeZone: string): Intl.DateTimeFormat {
  let f = formatters.get(timeZone);
  if (!f) {
    f = new Intl.DateTimeFormat("en-US", {
      timeZone,
      weekday: "short",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    });
    formatters.set(timeZone, f);
  }
  return f;
}

/** Local weekday (0=Sun) and minutes-from-midnight for a UTC instant in a tz. */
export function localParts(
  epochMs: number,
  timeZone: string,
): { weekday: number; minutes: number } {
  const parts = formatterFor(timeZone).formatToParts(new Date(epochMs));

  const map: Record<string, string> = {};
  for (const p of parts) map[p.type] = p.value;

  const weekdays: Record<string, number> = {
    Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6,
  };
  const weekday = weekdays[map.weekday] ?? 0;
  let hour = parseInt(map.hour ?? "0", 10);
  if (hour === 24) hour = 0; // some runtimes emit "24" for midnight
  const minute = parseInt(map.minute ?? "0", 10);
  return { weekday, minutes: hour * 60 + minute };
}

function overlaps(aStart: number, aEnd: number, bStart: number, bEnd: number): boolean {
  return aStart < bEnd && bStart < aEnd;
}

/**
 * Walk the window in chronological order, scoring every candidate slot that
 * satisfies the hard constraints (allowed weekday, and the whole slot inside the
 * local time-of-day range on that day). `visit` returning true stops the walk.
 *
 * Complexity is O(candidates × members × intervals); with 30-min steps even a
 * six-month window is a few thousand cheap checks.
 */
function eachCandidate(
  members: Member[],
  c: Constraints,
  visit: (slot: Slot) => boolean | void,
): void {
  const duration = c.durationMinutes * MINUTE;
  const step = c.stepMinutes * MINUTE;
  const allowed = new Set(c.allowedWeekdays);

  for (let start = c.windowStart; start + duration <= c.windowEnd; start += step) {
    const end = start + duration;

    const { weekday, minutes } = localParts(start, c.timezone);
    if (!allowed.has(weekday)) continue;
    if (minutes < c.dayStartMinutes) continue;
    if (minutes + c.durationMinutes > c.dayEndMinutes) continue;

    const availableUserIds: string[] = [];
    for (const m of members) {
      const isBusy = m.busy.some((b) => overlaps(start, end, b.start, b.end));
      if (!isBusy) availableUserIds.push(m.userId);
    }

    if (visit({ start, end, availableUserIds, score: availableUserIds.length })) return;
  }
}

/**
 * Slots meeting a hard quorum (default: everyone), best availability first with
 * ties broken by the earliest date. Prefer `findBestSlots` for the product
 * behaviour — this is the primitive for a caller that means a strict floor.
 */
export function findSlots(members: Member[], c: Constraints, maxResults = 10): Slot[] {
  const quorum = c.quorum ?? members.length;
  const slots: Slot[] = [];
  eachCandidate(members, c, (slot) => {
    if (slot.score >= quorum) slots.push(slot);
  });
  slots.sort((a, b) => b.score - a.score || a.start - b.start);
  return slots.slice(0, maxResults);
}

/**
 * The product behaviour: a date the *whole group* can make always wins, however
 * far out it is — so we return the earliest all-free slots and stop looking.
 * Only when the window holds no such date do we fall back to the best partial
 * turnout (at least `quorum`, defaulting to a majority), so the group is offered
 * something rather than nothing. The caller tells the user which happened.
 */
export function findBestSlots(members: Member[], c: Constraints, maxResults = 10): SlotSearch {
  const memberCount = members.length;
  const floor = Math.max(1, Math.min(c.quorum ?? majorityOf(memberCount), memberCount));
  const everyone: Slot[] = [];
  const partial: Slot[] = [];

  eachCandidate(members, c, (slot) => {
    if (slot.score === memberCount) {
      everyone.push(slot);
      // Candidates arrive in time order, so the first maxResults all-free slots
      // are already the answer — no need to search the rest of the window.
      if (everyone.length >= maxResults) return true;
    } else if (slot.score >= floor) {
      partial.push(slot);
    }
  });

  if (everyone.length) {
    return { slots: everyone, everyoneFree: true, memberCount, quorum: memberCount };
  }
  partial.sort((a, b) => b.score - a.score || a.start - b.start);
  return {
    slots: partial.slice(0, maxResults),
    everyoneFree: false,
    memberCount,
    quorum: floor,
  };
}
