// Deno tests for the scheduler. Run: `deno test supabase/functions/_shared/`
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { findSlots, localParts, type Constraints, type Member } from "./scheduler.ts";

// Build a UTC instant (month is 1-based here for readability).
const utc = (y: number, mo: number, d: number, h: number, mi = 0) =>
  Date.UTC(y, mo - 1, d, h, mi);

// 2026-08-15 is a Saturday; 2026-08-16 is a Sunday.

Deno.test("finds a weekend afternoon when everyone is free", () => {
  const c: Constraints = {
    windowStart: utc(2026, 8, 15, 0),
    windowEnd: utc(2026, 8, 17, 0),
    allowedWeekdays: [0, 6], // Sun, Sat
    dayStartMinutes: 12 * 60,
    dayEndMinutes: 17 * 60,
    durationMinutes: 180,
    stepMinutes: 30,
    timezone: "UTC",
    quorum: 3,
  };
  const members: Member[] = [
    { userId: "a", busy: [] },
    { userId: "b", busy: [{ start: utc(2026, 8, 15, 12), end: utc(2026, 8, 15, 14) }] },
    { userId: "c", busy: [] },
  ];

  const slots = findSlots(members, c);
  assertEquals(slots[0].score, 3); // a slot exists where all three are free

  for (const s of slots) {
    const p = localParts(s.start, "UTC");
    assertEquals([0, 6].includes(p.weekday), true);       // weekend only
    assertEquals(p.minutes >= 12 * 60, true);             // afternoon only
    assertEquals(p.minutes + 180 <= 17 * 60, true);       // fits the window
  }
});

Deno.test("excludes a member whose busy block overlaps the whole window", () => {
  const c: Constraints = {
    windowStart: utc(2026, 8, 15, 12),
    windowEnd: utc(2026, 8, 15, 17),
    allowedWeekdays: [6],
    dayStartMinutes: 12 * 60,
    dayEndMinutes: 17 * 60,
    durationMinutes: 60,
    stepMinutes: 60,
    timezone: "UTC",
    quorum: 1,
  };
  const members: Member[] = [
    { userId: "a", busy: [{ start: utc(2026, 8, 15, 12), end: utc(2026, 8, 15, 17) }] },
  ];
  assertEquals(findSlots(members, c).length, 0);
});

Deno.test("respects the quorum", () => {
  const c: Constraints = {
    windowStart: utc(2026, 8, 15, 12),
    windowEnd: utc(2026, 8, 15, 15),
    allowedWeekdays: [6],
    dayStartMinutes: 12 * 60,
    dayEndMinutes: 15 * 60,
    durationMinutes: 60,
    stepMinutes: 60,
    timezone: "UTC",
    quorum: 2,
  };
  const members: Member[] = [
    { userId: "a", busy: [] },
    { userId: "b", busy: [{ start: utc(2026, 8, 15, 0), end: utc(2026, 8, 16, 0) }] },
  ];
  assertEquals(findSlots(members, c).length, 0); // only one free, quorum is two
});
