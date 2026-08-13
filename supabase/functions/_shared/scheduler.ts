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

const MINUTE = 60_000;

/** Local weekday (0=Sun) and minutes-from-midnight for a UTC instant in a tz. */
export function localParts(
  epochMs: number,
  timeZone: string,
): { weekday: number; minutes: number } {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(new Date(epochMs));

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
 * Enumerate candidate slots satisfying the hard constraints and rank them by
 * availability. Complexity is O(candidates × members × intervals); with a
 * bounded window and 30-min steps this is a few thousand cheap checks.
 */
export function findSlots(members: Member[], c: Constraints, maxResults = 10): Slot[] {
  const quorum = c.quorum ?? members.length;
  const duration = c.durationMinutes * MINUTE;
  const step = c.stepMinutes * MINUTE;
  const allowed = new Set(c.allowedWeekdays);
  const slots: Slot[] = [];

  for (let start = c.windowStart; start + duration <= c.windowEnd; start += step) {
    const end = start + duration;

    // Hard constraints: allowed weekday, and the whole slot fits inside the
    // local time-of-day window on that same day.
    const { weekday, minutes } = localParts(start, c.timezone);
    if (!allowed.has(weekday)) continue;
    if (minutes < c.dayStartMinutes) continue;
    if (minutes + c.durationMinutes > c.dayEndMinutes) continue;

    const availableUserIds: string[] = [];
    for (const m of members) {
      const isBusy = m.busy.some((b) => overlaps(start, end, b.start, b.end));
      if (!isBusy) availableUserIds.push(m.userId);
    }

    if (availableUserIds.length >= quorum) {
      slots.push({ start, end, availableUserIds, score: availableUserIds.length });
    }
  }

  // Best availability first; ties broken by the earliest date.
  slots.sort((a, b) => b.score - a.score || a.start - b.start);
  return slots.slice(0, maxResults);
}
