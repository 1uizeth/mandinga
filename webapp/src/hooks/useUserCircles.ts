"use client";

import { useMemo } from "react";
import { useReadContracts } from "wagmi";
import { useShieldedId } from "./useShieldedId";
import { SAVINGS_CIRCLE } from "@/lib/contracts";
import SavingsCircleAbi from "@/lib/abi/ISavingsCircle.json";

/** CircleStatus: 0=FORMING, 1=ACTIVE, 2=COMPLETED */
export type CircleStatus = 0 | 1 | 2;

export interface UserCircle {
  circleId: bigint;
  poolSize: bigint;
  memberCount: number;
  contributionPerMember: bigint;
  roundDuration: bigint;
  nextRoundTimestamp: bigint;
  filledSlots: number;
  roundsCompleted: number;
  status: CircleStatus;
  slot: number;
}

export function useUserCircles() {
  const { shieldedId, isLoading: shieldedLoading } = useShieldedId();

  const { data: nextCircleId } = useReadContracts({
    contracts: [
      {
        address: SAVINGS_CIRCLE,
        abi: SavingsCircleAbi.abi as never,
        functionName: "nextCircleId",
      },
    ],
  });

  const count = nextCircleId?.[0]?.result as bigint | undefined;
  const circleCount = count !== undefined ? Number(count) : 0;

  const circleContracts = useMemo(() => {
    if (circleCount === 0) return [];
    const contracts: {
      address: `0x${string}`;
      abi: never;
      functionName: "circles" | "getMembers";
      args: [bigint];
    }[] = [];
    for (let i = 0; i < circleCount; i++) {
      contracts.push(
        {
          address: SAVINGS_CIRCLE,
          abi: SavingsCircleAbi.abi as never,
          functionName: "circles",
          args: [BigInt(i)],
        },
        {
          address: SAVINGS_CIRCLE,
          abi: SavingsCircleAbi.abi as never,
          functionName: "getMembers",
          args: [BigInt(i)],
        }
      );
    }
    return contracts;
  }, [circleCount]);
  const { data: circlesData, isLoading: circlesLoading } = useReadContracts({
    contracts: circleContracts,
  });

  const circles: UserCircle[] = useMemo(() => {
    if (!circlesData || circleCount === 0) return [];

    const result: UserCircle[] = [];

    for (let i = 0; i < circleCount; i++) {
      const circleIdx = i * 2;
      const membersIdx = i * 2 + 1;
      const circleResult = circlesData[circleIdx]?.result;
      const membersResult = circlesData[membersIdx]?.result as
        | readonly `0x${string}`[]
        | undefined;

      if (!circleResult || !membersResult) continue;

      const slot = shieldedId
        ? membersResult.findIndex((m) => (m as string).toLowerCase() === (shieldedId as string).toLowerCase())
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
      result.push({
        circleId: BigInt(i),
        poolSize: c[0],
        memberCount: c[1],
        contributionPerMember: c[2],
        roundDuration: c[3],
        nextRoundTimestamp: c[4],
        filledSlots: c[5],
        roundsCompleted: c[6],
        status: c[8] as CircleStatus,
        slot,
      });
    }
    return result;
  }, [shieldedId, circlesData, circleCount]);

  const isLoading = shieldedLoading || circlesLoading;

  return {
    circles,
    isLoading,
  };
}
