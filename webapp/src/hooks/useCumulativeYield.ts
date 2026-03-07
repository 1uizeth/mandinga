"use client";

import { useReadContract } from "wagmi";
import { useSavingsPosition } from "./useSavingsPosition";
import { SAVINGS_ACCOUNT, YIELD_ROUTER } from "@/lib/contracts";
import SavingsAccountAbi from "@/lib/abi/ISavingsAccount.json";
import YieldRouterAbi from "@/lib/abi/IYieldRouter.json";

/**
 * Returns cumulative yield derived from share price appreciation.
 * Yield is computed as: (position.balance / totalPrincipal) * savingsAccountValue - position.balance
 */
export function useCumulativeYield() {
  const { position, isLoading: positionLoading } = useSavingsPosition();

  const { data: totalPrincipal } = useReadContract({
    address: SAVINGS_ACCOUNT,
    abi: SavingsAccountAbi.abi as never,
    functionName: "totalPrincipal",
  });

  const { data: savingsAccountShares } = useReadContract({
    address: YIELD_ROUTER,
    abi: YieldRouterAbi.abi as never,
    functionName: "balanceOf",
    args: [SAVINGS_ACCOUNT],
  });

  const { data: savingsAccountValue } = useReadContract({
    address: YIELD_ROUTER,
    abi: YieldRouterAbi.abi as never,
    functionName: "convertToAssets",
    args: savingsAccountShares !== undefined ? [savingsAccountShares] : undefined,
  });

  console.log("savingsAccountValue", savingsAccountValue);
  console.log("totalPrincipal", totalPrincipal);
  console.log("savingsAccountShares", savingsAccountShares);
  console.log("position", position);

  const isLoading =
    positionLoading ||
    totalPrincipal === undefined ||
    savingsAccountShares === undefined ||
    savingsAccountValue === undefined;

  let cumulativeYieldUsdc = BigInt(0);

  if (
    !isLoading &&
    position &&
    totalPrincipal !== undefined &&
    savingsAccountValue !== undefined
  ) {
    const totalPrincipalBig = BigInt(totalPrincipal);

    if (totalPrincipalBig === BigInt(0)) {
      cumulativeYieldUsdc = BigInt(0);
    } else {
      const positionValue =
        (position.balance * BigInt(savingsAccountValue)) / totalPrincipalBig;

      if (positionValue > position.balance) {
        cumulativeYieldUsdc = positionValue - position.balance;
      }
    }
  }

  return {
    cumulativeYieldUsdc,
    isLoading,
  };
}
