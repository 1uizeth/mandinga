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

  const { data: totalPrincipal, isLoading: totalPrincipalLoading } = useReadContract({
    address: SAVINGS_ACCOUNT,
    abi: SavingsAccountAbi.abi as never,
    functionName: "totalPrincipal",
  });

  const { data: savingsAccountShares, isLoading: sharesLoading } = useReadContract({
    address: YIELD_ROUTER,
    abi: YieldRouterAbi.abi as never,
    functionName: "balanceOf",
    args: [SAVINGS_ACCOUNT],
  });

  const { data: savingsAccountValue, isLoading: valueLoading } = useReadContract({
    address: YIELD_ROUTER,
    abi: YieldRouterAbi.abi as never,
    functionName: "convertToAssets",
    args: savingsAccountShares !== undefined ? [savingsAccountShares] : undefined,
  });

  const isLoading =
    positionLoading ||
    totalPrincipalLoading ||
    sharesLoading ||
    (savingsAccountShares !== undefined && valueLoading);

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
