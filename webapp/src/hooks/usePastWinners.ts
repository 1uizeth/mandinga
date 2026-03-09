"use client";

import { useMemo } from "react";
import { useReadContracts } from "wagmi";
import { SAVINGS_CIRCLE } from "@/lib/contracts";
import SavingsCircleAbi from "@/lib/abi/ISavingsCircle.json";

export interface PastWinner {
  slot: number;
  shieldedId: `0x${string}`;
}

export function usePastWinners(
  circleId: bigint | undefined,
  memberCount: number
) {
  const contracts = useMemo(() => {
    if (circleId === undefined || memberCount <= 0) return [];
    const list: {
      address: `0x${string}`;
      abi: never;
      functionName: "payoutReceived" | "pendingPayout" | "getMember";
      args: [bigint, number];
      slot?: number;
    }[] = [];
    for (let slot = 0; slot < memberCount; slot++) {
      list.push(
        {
          address: SAVINGS_CIRCLE,
          abi: SavingsCircleAbi.abi as never,
          functionName: "payoutReceived" as const,
          args: [circleId, slot] as [bigint, number],
          slot,
        },
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

  const pastWinners: PastWinner[] = useMemo(() => {
    if (!data || memberCount <= 0) return [];
    const result: PastWinner[] = [];
    for (let slot = 0; slot < memberCount; slot++) {
      const baseIdx = slot * 3;
      const payoutReceivedResult = data[baseIdx]?.result;
      const pendingPayoutResult = data[baseIdx + 1]?.result;
      const memberResult = data[baseIdx + 2]?.result as `0x${string}` | undefined;
      if (
        payoutReceivedResult === true &&
        pendingPayoutResult === false &&
        memberResult
      ) {
        result.push({ slot, shieldedId: memberResult });
      }
    }
    return result;
  }, [data, memberCount]);

  return { pastWinners };
}
