// Stress and edge tests for the scheduler — the parts that only bite at real
// scale or on awkward calendars: six-month windows, big groups, packed busy
// lists, DST, and timezones that disagree about what day it is.
//
// Run: `deno test supabase/functions/_shared/`
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  findBestSlots,
  localParts,
  majorityOf,
  type Constraints,
  type Member,
} from "./scheduler.ts";

const DAY = 86_400_000;
const utc = (y: number, mo: number, d: number, h = 0, mi = 0) => Date.UTC(y, mo - 1, d, h, mi);

const weekendAfternoons = (windowStart: number, months = 6): Constraints => ({
  windowStart,
  windowEnd: windowStart + Math.round(months * 30.5) * DAY,
  allowedWeekdays: [0, 6],
  dayStartMinutes: 12 * 60,
  dayEndMinutes: 17 * 60,
  durationMinutes: 120,
  stepMinutes: 30,
  timezone: "UTC",
});

// --- scale ------------------------------------------------------------------

Deno.test("stress: 12 people, 6-month window, ~250 busy blocks each", () => {
  const start = utc(2026, 8, 15);
  const c = weekendAfternoons(start);
  const members: Member[] = [];
  for (let m = 0; m < 12; m++) {
    const busy = [];
    // Every member is busy on a different two days each week for six months.
    for (let d = m % 7; d < 190; d += 7) {
      busy.push({ start: start + d * DAY, end: start + (d + 1) * DAY });
      busy.push({ start: start + (d + 2) * DAY, end: start + (d + 3) * DAY });
    }
    members.push({ userId: `u${m}`, busy });
  }

  const t0 = performance.now();
  const res = findBestSlots(members, c, 5);
  const ms = performance.now() - t0;

  // Correctness first: whatever it returns must be internally consistent.
  for (const slot of res.slots) {
    assertEquals(slot.score, slot.availableUserIds.length);
    assertEquals(slot.end - slot.start, c.durationMinutes * 60_000);
    const p = localParts(slot.start, c.timezone);
    assertEquals([0, 6].includes(p.weekday), true);
    assertEquals(p.minutes >= c.dayStartMinutes, true);
    assertEquals(p.minutes + c.durationMinutes <= c.dayEndMinutes, true);
  }
  // A six-month search is a user-facing wait; a couple of seconds would be a bug.
  assertEquals(ms < 2000, true, `six-month search took ${ms.toFixed(0)}ms`);
});

Deno.test("stress: a fully booked group returns nothing rather than hanging", () => {
  const start = utc(2026, 8, 15);
  const c = weekendAfternoons(start);
  const solidYear = [{ start, end: start + 400 * DAY }];
  const members: Member[] = Array.from({ length: 8 }, (_, i) => ({
    userId: `u${i}`,
    busy: solidYear,
  }));

  const res = findBestSlots(members, c, 5);
  assertEquals(res.slots.length, 0);
  assertEquals(res.everyoneFree, false);
});

Deno.test("stress: the early exit doesn't skip a better earlier date", () => {
  // Everyone free the whole window: the answer must be the first five
  // candidates in time order, not five arbitrary ones.
  const start = utc(2026, 8, 15);
  const c = weekendAfternoons(start);
  const members: Member[] = Array.from({ length: 6 }, (_, i) => ({ userId: `u${i}`, busy: [] }));

  const res = findBestSlots(members, c, 5);
  assertEquals(res.everyoneFree, true);
  assertEquals(res.slots.length, 5);
  const starts = res.slots.map((s) => s.start);
  assertEquals([...starts].sort((a, b) => a - b), starts, "chronological");
  assertEquals(starts[0], utc(2026, 8, 15, 12), "the very first candidate");
});

// --- calendars that fight back ----------------------------------------------

Deno.test("edge: DST — every slot still sits inside the local afternoon", () => {
  // 2026-11-01 is the US fall-back. A slot built by adding fixed milliseconds
  // can drift an hour across it; the constraint is local, so it must not.
  const tz = "America/Los_Angeles";
  const start = Date.UTC(2026, 9, 20); // 20 Oct, before the change
  const c: Constraints = {
    ...weekendAfternoons(start, 2),
    timezone: tz,
    allowedWeekdays: [0, 1, 2, 3, 4, 5, 6],
  };
  const res = findBestSlots([{ userId: "a", busy: [] }], c, 200);

  assertEquals(res.slots.length > 0, true);
  for (const slot of res.slots) {
    const p = localParts(slot.start, tz);
    assertEquals(p.minutes >= c.dayStartMinutes, true);
    assertEquals(p.minutes + c.durationMinutes <= c.dayEndMinutes, true);
  }
  // The window spans the change, so both offsets must appear.
  const before = res.slots.some((s) => s.start < Date.UTC(2026, 10, 1));
  const after = res.slots.some((s) => s.start > Date.UTC(2026, 10, 2));
  assertEquals(before && after, true, "window should straddle the DST change");
});

Deno.test("edge: the same instant is a different weekday in Tokyo and LA", () => {
  // Sat 19:00 LA == Sun 11:00 Tokyo. A Sunday-only search must find it in
  // Tokyo and reject it in LA.
  const instant = Date.UTC(2026, 7, 16, 2); // Sun 02:00 UTC
  const base = {
    windowStart: instant,
    windowEnd: instant + 3 * 3600_000,
    allowedWeekdays: [0], // Sunday
    dayStartMinutes: 0,
    dayEndMinutes: 24 * 60,
    durationMinutes: 60,
    stepMinutes: 60,
  };
  const member: Member[] = [{ userId: "a", busy: [] }];

  const tokyo = findBestSlots(member, { ...base, timezone: "Asia/Tokyo" }, 5);
  const la = findBestSlots(member, { ...base, timezone: "America/Los_Angeles" }, 5);

  assertEquals(tokyo.slots.length > 0, true, "Sunday morning in Tokyo");
  assertEquals(la.slots.length, 0, "still Saturday evening in LA");
});

Deno.test("edge: a busy block that only clips the slot still excludes you", () => {
  const start = utc(2026, 8, 15, 12);
  const c: Constraints = {
    windowStart: start,
    windowEnd: start + 4 * 3600_000,
    allowedWeekdays: [6],
    dayStartMinutes: 12 * 60,
    dayEndMinutes: 16 * 60,
    durationMinutes: 120,
    stepMinutes: 120,
    timezone: "UTC",
  };
  const members: Member[] = [
    { userId: "free", busy: [] },
    // one minute of overlap at the very end of the first slot
    { userId: "clipped", busy: [{ start: start + 119 * 60_000, end: start + 3 * 3600_000 }] },
  ];

  const res = findBestSlots(members, c, 5);
  assertEquals(res.everyoneFree, false, "no slot works for both");
  assertEquals(res.slots[0].availableUserIds, ["free"]);
});

Deno.test("edge: back-to-back is not a clash", () => {
  const start = utc(2026, 8, 15, 12);
  const c: Constraints = {
    windowStart: start,
    windowEnd: start + 2 * 3600_000,
    allowedWeekdays: [6],
    dayStartMinutes: 12 * 60,
    dayEndMinutes: 14 * 60,
    durationMinutes: 120,
    stepMinutes: 60,
    timezone: "UTC",
  };
  // Busy right up to the start, and again from the end.
  const members: Member[] = [{
    userId: "a",
    busy: [
      { start: start - 3600_000, end: start },
      { start: start + 2 * 3600_000, end: start + 3 * 3600_000 },
    ],
  }];

  const res = findBestSlots(members, c, 5);
  assertEquals(res.everyoneFree, true);
  assertEquals(res.slots.length, 1);
});

// --- degenerate input -------------------------------------------------------

Deno.test("edge: degenerate constraints return nothing, not garbage", () => {
  const start = utc(2026, 8, 15, 12);
  const member: Member[] = [{ userId: "a", busy: [] }];
  const base = weekendAfternoons(start, 1);

  assertEquals(findBestSlots(member, { ...base, allowedWeekdays: [] }).slots.length, 0);
  assertEquals(findBestSlots(member, { ...base, windowEnd: base.windowStart }).slots.length, 0);
  assertEquals(
    findBestSlots(member, { ...base, durationMinutes: 10 * 60 }).slots.length,
    0,
    "10h can't fit in a 5h window",
  );
  assertEquals(findBestSlots(member, base, 0).slots.length, 0, "maxResults 0");
});

Deno.test("edge: quorum above the group size can't make a slot unreachable", () => {
  const start = utc(2026, 8, 15);
  const c = { ...weekendAfternoons(start, 1), quorum: 99 };
  const members: Member[] = [{ userId: "a", busy: [] }, { userId: "b", busy: [] }];

  const res = findBestSlots(members, c, 3);
  assertEquals(res.everyoneFree, true, "both are free — that clears any sane floor");
  assertEquals(res.slots.length, 3);
});

Deno.test("edge: an empty group is not treated as everyone-free noise", () => {
  const res = findBestSlots([], weekendAfternoons(utc(2026, 8, 15), 1), 3);
  assertEquals(res.memberCount, 0);
  for (const slot of res.slots) assertEquals(slot.availableUserIds.length, 0);
});

Deno.test("edge: majorityOf rounds up", () => {
  assertEquals(majorityOf(1), 1);
  assertEquals(majorityOf(2), 1);
  assertEquals(majorityOf(3), 2);
  assertEquals(majorityOf(6), 3);
  assertEquals(majorityOf(7), 4);
});
