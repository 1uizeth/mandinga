"use client";

import { useCallback } from "react";
import { useReadContract } from "wagmi";
import { useShieldedId } from "./useShieldedId";
import { SAVINGS_ACCOUNT } from "@/lib/contracts";
import SavingsAccountAbi from "@/lib/abi/ISavingsAccount.json";

export interface SavingsPosition {
  balance: bigint;
  circleObligation: bigint;
  withdrawable: bigint;
  yieldEarnedTotal: bigint;
  isActive: boolean;
}

export interface Position {
  balance: string;
  circleObligation: string;
  yieldEarnedTotal: string;
  isActive: boolean;
}

export function useSavingsPosition() {
  const { shieldedId, isLoading: shieldedLoading } = useShieldedId();
  console.log("shieldedId", shieldedId);
  const {
    data: positionData,
    isLoading: positionLoading,
    refetch: refetchPosition,
  } = useReadContract({
    address: SAVINGS_ACCOUNT,
    abi: SavingsAccountAbi.abi as never,
    functionName: "getPosition",
    args: shieldedId ? [shieldedId] : undefined,
  }) as { data: Position; isLoading: boolean; refetch: () => Promise<unknown> };

  const {
    data: withdrawable,
    isLoading: withdrawableLoading,
    refetch: refetchWithdrawable,
  } = useReadContract({
    address: SAVINGS_ACCOUNT,
    abi: SavingsAccountAbi.abi as never,
    functionName: "getWithdrawableBalance",
    args: shieldedId ? [shieldedId] : undefined,
  });

  const isLoading =
    shieldedLoading || positionLoading || withdrawableLoading;

  const position: SavingsPosition | null =
    positionData && withdrawable !== undefined
      ? {
          balance: BigInt(positionData.balance),
          circleObligation: BigInt(positionData.circleObligation),
          withdrawable: BigInt(withdrawable),
          yieldEarnedTotal: BigInt(positionData.yieldEarnedTotal),
          isActive: BigInt(positionData.balance) > BigInt(0),
        }
      : null;

  const refetch = useCallback(async () => {
    await Promise.all([refetchPosition(), refetchWithdrawable()]);
  }, [refetchPosition, refetchWithdrawable]);

  return {
    position,
    shieldedId,
    isLoading,
    refetch,
  };
}
