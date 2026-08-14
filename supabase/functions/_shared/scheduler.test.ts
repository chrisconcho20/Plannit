// Deno tests for the scheduler. Run: `deno test supabase/functions/_shared/`
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  findBestSlots,
  findSlots,
  localParts,
  majorityOf,
  type Constraints,
  type Member,
} from "./scheduler.ts";

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

// --- findBestSlots: everyone-free wins, majority is only a fallback ---------

// Sat 15th afternoon, Sun 16th afternoon, both 12:00–17:00 UTC, 2h slots.
const weekend: Constraints = {
  windowStart: utc(2026, 8, 15, 0),
  windowEnd: utc(2026, 8, 17, 0),
  allowedWeekdays: [0, 6],
  dayStartMinutes: 12 * 60,
  dayEndMinutes: 17 * 60,
  durationMinutes: 120,
  stepMinutes: 60,
  timezone: "UTC",
};

Deno.test("prefers a later date everyone can make over an earlier partial one", () => {
  const members: Member[] = [
    { userId: "a", busy: [] },
    { userId: "b", busy: [{ start: utc(2026, 8, 15, 0), end: utc(2026, 8, 16, 0) }] }, // out all Saturday
    { userId: "c", busy: [] },
  ];

  const res = findBestSlots(members, weekend);
  assertEquals(res.everyoneFree, true);
  assertEquals(res.quorum, 3);
  assertEquals(res.slots.length > 0, true);
  for (const s of res.slots) {
    assertEquals(s.score, 3);
    assertEquals(s.start >= utc(2026, 8, 16, 0), true); // Sunday, not the earlier Saturday
  }
});

Deno.test("falls back to the best turnout when no date works for everyone", () => {
  const members: Member[] = [
    { userId: "a", busy: [] },
    { userId: "b", busy: [] },
    { userId: "c", busy: [{ start: utc(2026, 8, 15, 0), end: utc(2026, 8, 17, 0) }] }, // out all weekend
  ];

  const res = findBestSlots(members, weekend);
  assertEquals(res.everyoneFree, false);
  assertEquals(res.memberCount, 3);
  assertEquals(res.quorum, majorityOf(3)); // 2
  assertEquals(res.slots[0].score, 2);
  assertEquals(res.slots[0].start, utc(2026, 8, 15, 12)); // earliest of the best
});

Deno.test("returns nothing when even the majority can't make it", () => {
  const busyAllWeekend = [{ start: utc(2026, 8, 15, 0), end: utc(2026, 8, 17, 0) }];
  const members: Member[] = [
    { userId: "a", busy: [] },
    { userId: "b", busy: busyAllWeekend },
    { userId: "c", busy: busyAllWeekend },
  ];

  const res = findBestSlots(members, weekend);
  assertEquals(res.everyoneFree, false);
  assertEquals(res.slots.length, 0); // 1 of 3 is below the majority floor
});

Deno.test("stops after maxResults all-free slots", () => {
  const members: Member[] = [{ userId: "a", busy: [] }, { userId: "b", busy: [] }];
  const res = findBestSlots(members, weekend, 3);
  assertEquals(res.slots.length, 3);
  assertEquals(res.everyoneFree, true);
  // Earliest first: 12:00, 13:00, 14:00 on the Saturday.
  assertEquals(res.slots.map((s) => s.start), [
    utc(2026, 8, 15, 12),
    utc(2026, 8, 15, 13),
    utc(2026, 8, 15, 14),
  ]);
});

Deno.test("an explicit quorum lowers the fallback floor", () => {
  const busyAllWeekend = [{ start: utc(2026, 8, 15, 0), end: utc(2026, 8, 17, 0) }];
  const members: Member[] = [
    { userId: "a", busy: [] },
    { userId: "b", busy: busyAllWeekend },
    { userId: "c", busy: busyAllWeekend },
  ];

  const res = findBestSlots(members, { ...weekend, quorum: 1 });
  assertEquals(res.everyoneFree, false);
  assertEquals(res.quorum, 1);
  assertEquals(res.slots[0].score, 1);
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
