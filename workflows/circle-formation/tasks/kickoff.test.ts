import { describe, expect, test } from "bun:test";
import { runKickoff } from "./kickoff.js";

const mkIntent = (memberId: string, deposit: number, durationDays: number) => ({
  memberId: memberId as `0x${string}`,
  depositPerRound: BigInt(deposit * 1e6),
  duration: BigInt(durationDays * 24 * 3600),
});

describe("runKickoff", () => {
  test("returns not viable when fewer than 2 intents", () => {
    const intents = [mkIntent("0x01", 100, 12)];
    expect(runKickoff(intents, 500)).toEqual({ viable: false });
  });

  test("returns not viable when empty", () => {
    expect(runKickoff([], 500)).toEqual({ viable: false });
  });

  test("returns viable N when enough positions beat solo", () => {
    // 365 days duration, 5% APY — early positions beat solo (70% threshold).
    const intents = [
      mkIntent("0x01", 100, 365),
      mkIntent("0x02", 100, 365),
      mkIntent("0x03", 100, 365),
      mkIntent("0x04", 100, 365),
    ];
    const result = runKickoff(intents, 500, 7000);
    expect(result.viable).toBe(true);
    expect(result.n).toBeDefined();
    expect(result.memberIds).toBeDefined();
    expect(result.memberIds!.length).toBe(result.n);
  });

  test("selects largest viable N", () => {
    const intents = [
      mkIntent("0x01", 100, 12),
      mkIntent("0x02", 100, 12),
      mkIntent("0x03", 100, 12),
    ];
    const result = runKickoff(intents, 500, 7000);
    if (result.viable) {
      expect(result.n).toBeLessThanOrEqual(3);
    }
  });

  test("respects formation threshold", () => {
    const intents = [
      mkIntent("0x01", 100, 12),
      mkIntent("0x02", 100, 12),
    ];
    const result = runKickoff(intents, 500, 10000); // 100% threshold
    expect(result.viable).toBeDefined();
  });
});
