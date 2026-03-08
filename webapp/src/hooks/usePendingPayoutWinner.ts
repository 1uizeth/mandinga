"use client";

import { useMemo } from "react";
import { useReadContracts } from "wagmi";
import { SAVINGS_CIRCLE } from "@/lib/contracts";
import SavingsCircleAbi from "@/lib/abi/ISavingsCircle.json";

export interface PendingPayoutWinner {
  winningSlot: number;
  winningShieldedId: `0x${string}`;
}

export function usePendingPayoutWinner(
  circleId: bigint | undefined,
  memberCount: number
) {
  const contracts = useMemo(() => {
    if (circleId === undefined || memberCount <= 0) return [];
    const list: {
      address: `0x${string}`;
      abi: never;
      functionName: "pendingPayout" | "getMember";
      args: [bigint] | [bigint, number];
      slot?: number;
    }[] = [];
    for (let slot = 0; slot < memberCount; slot++) {
      list.push(
        {
          address: SAVINGS_CIRCLE,
          abi: SavingsCircleAbi.abi as never,
          functionName: "pendingPayout" as const,
          args: [circleId, slot] as [bigint, number],
          slot,
        },
        {
          address: SAVINGS_CIRCLE,
          abi: SavingsCircleAbi.abi as never,
          functionName: "getMember" as const,
          args: [circleId, slot] as [bigint, number],
          slot,
        }
      );
    }
    return list;
  }, [circleId, memberCount]);

  const { data } = useReadContracts({ contracts });

  const winner: PendingPayoutWinner | null = useMemo(() => {
    if (!data || memberCount <= 0) return null;
    for (let slot = 0; slot < memberCount; slot++) {
      const pendingIdx = slot * 2;
      const memberIdx = slot * 2 + 1;
      const pendingResult = data[pendingIdx]?.result;
      const memberResult = data[memberIdx]?.result as `0x${string}` | undefined;
      if (pendingResult === true && memberResult) {
        return {
          winningSlot: slot,
          winningShieldedId: memberResult,
        };
      }
    }
    return null;
  }, [data, memberCount]);

  return { winner };
}
