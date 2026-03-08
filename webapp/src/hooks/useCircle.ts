"use client";

import { useMemo } from "react";
import { useReadContracts } from "wagmi";
import { useShieldedId } from "./useShieldedId";
import { SAVINGS_CIRCLE } from "@/lib/contracts";
import SavingsCircleAbi from "@/lib/abi/ISavingsCircle.json";
import type { UserCircle, CircleStatus } from "@/hooks/useUserCircles";

export interface CircleWithMembers extends UserCircle {
  minDepositPerRound: bigint;
  members: readonly `0x${string}`[];
  pendingVrfRequestId: bigint;
}

export function useCircle(circleId: bigint | number | string | undefined) {
  const id = useMemo(() => {
    if (circleId === undefined || circleId === null) return undefined;
    const n = BigInt(circleId);
    return n >= 0 ? n : undefined;
  }, [circleId]);

  const { shieldedId, isLoading: shieldedLoading } = useShieldedId();

  const contracts = useMemo(() => {
    if (id === undefined) return [];
    return [
      {
        address: SAVINGS_CIRCLE,
        abi: SavingsCircleAbi.abi as never,
        functionName: "nextCircleId" as const,
      },
      {
        address: SAVINGS_CIRCLE,
        abi: SavingsCircleAbi.abi as never,
        functionName: "circles" as const,
        args: [id] as [bigint],
      },
      {
        address: SAVINGS_CIRCLE,
        abi: SavingsCircleAbi.abi as never,
        functionName: "getMembers" as const,
        args: [id] as [bigint],
      },
    ];
  }, [id]);

  const { data, isLoading: contractsLoading } = useReadContracts({
    contracts,
  });

  const circle: CircleWithMembers | null = useMemo(() => {
    if (!data || id === undefined) return null;
    const nextId = data[0]?.result as bigint | undefined;
    if (nextId !== undefined && id >= nextId) return null;

    const circleResult = data[1]?.result;
    const membersResult = data[2]?.result as readonly `0x${string}`[] | undefined;

    if (!circleResult || !membersResult) return null;

    const shieldedIdLower = shieldedId
      ? (shieldedId as string).toLowerCase()
      : null;
    const slot =
      shieldedIdLower !== null
        ? membersResult.findIndex(
            (m) => (m as string).toLowerCase() === shieldedIdLower
          )
        : -1;

    const c = circleResult as readonly [
      bigint,
      number,
      bigint,
      bigint,
      bigint,
      number,
      number,
      bigint,
      number,
      bigint,
    ];

    return {
      circleId: id,
      poolSize: c[0],
      memberCount: c[1],
      contributionPerMember: c[2],
      roundDuration: c[3],
      nextRoundTimestamp: c[4],
      filledSlots: c[5],
      roundsCompleted: c[6],
      pendingVrfRequestId: c[7],
      status: c[8] as CircleStatus,
      slot,
      minDepositPerRound: c[9],
      members: membersResult,
    };
  }, [data, id, shieldedId]);

  return {
    circle,
    isLoading: shieldedLoading || contractsLoading,
  };
}
