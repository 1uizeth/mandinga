"use client";

import type { UserCircle } from "./useUserCircles";

const MOCK_CIRCLES: UserCircle[] = [
  {
    circleId: BigInt(0),
    poolSize: BigInt(5_000_000_000), // 5,000 USDC
    memberCount: 5,
    contributionPerMember: BigInt(1_000_000_000), // 1,000 USDC
    roundDuration: BigInt(2592000), // 30 days
    nextRoundTimestamp: BigInt(Math.floor(Date.now() / 1000) + 86400 * 12),
    filledSlots: 5,
    roundsCompleted: 1,
    status: 1, // Active
    slot: 2,
  },
  {
    circleId: BigInt(1),
    poolSize: BigInt(1_500_000_000), // 1,500 USDC
    memberCount: 3,
    contributionPerMember: BigInt(500_000_000), // 500 USDC
    roundDuration: BigInt(604800), // 7 days
    nextRoundTimestamp: BigInt(Math.floor(Date.now() / 1000) + 86400 * 3),
    filledSlots: 2,
    roundsCompleted: 0,
    status: 0, // Forming
    slot: 0,
  },
  {
    circleId: BigInt(2),
    poolSize: BigInt(10_000_000_000), // 10,000 USDC
    memberCount: 10,
    contributionPerMember: BigInt(1_000_000_000), // 1,000 USDC
    roundDuration: BigInt(2592000),
    nextRoundTimestamp: BigInt(0),
    filledSlots: 10,
    roundsCompleted: 10,
    status: 2, // Ended
    slot: 7,
  },
];

export function useMockCircles() {
  return { circles: MOCK_CIRCLES, isLoading: false };
}
