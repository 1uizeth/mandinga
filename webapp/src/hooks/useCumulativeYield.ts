"use client";

import { useSavingsPosition } from "./useSavingsPosition";

/**
 * Returns cumulative yield earned since first deposit.
 * Source: SavingsAccount position.yieldEarnedTotal (tracked on-chain).
 */
export function useCumulativeYield() {
  const { position, isLoading } = useSavingsPosition();

  console.log("position", position);
  console.log("position?.yieldEarnedTotal", position?.yieldEarnedTotal);
  const cumulativeYieldUsdc = position?.yieldEarnedTotal ?? BigInt(0);

  return {
    cumulativeYieldUsdc,
    isLoading,
  };
}
