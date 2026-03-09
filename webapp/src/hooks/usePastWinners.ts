"use client";

import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { useReadContracts } from "wagmi";
import { usePublicClient } from "wagmi";
import { parseAbiItem } from "viem";
import { SAVINGS_CIRCLE } from "@/lib/contracts";
import SavingsCircleAbi from "@/lib/abi/ISavingsCircle.json";

export interface PastWinner {
  roundNumber: number;
  slot: number;
  shieldedId: `0x${string}`;
}

const MEMBER_SELECTED_EVENT = parseAbiItem(
  "event MemberSelected(uint256 indexed circleId, uint16 slot, bytes32 shieldedId)"
);

/**
 * Returns past winners in round order (round 1, 2, 3, ...).
 * Uses MemberSelected events for round order; filters to only those who have claimed.
 */
export function usePastWinners(
  circleId: bigint | undefined,
  memberCount: number
) {
  const publicClient = usePublicClient();

  const { data: memberSelectedEvents } = useQuery({
    queryKey: ["memberSelectedAll", circleId?.toString(), SAVINGS_CIRCLE],
    queryFn: async () => {
      if (!publicClient || circleId === undefined) return [];
      const logs = await publicClient.getLogs({
        address: SAVINGS_CIRCLE,
        event: MEMBER_SELECTED_EVENT,
        args: { circleId },
      });
      return logs;
    },
    enabled: !!publicClient && circleId !== undefined,
  });

  const contracts = useMemo(() => {
    if (circleId === undefined || memberCount <= 0) return [];
    const list: {
      address: `0x${string}`;
      abi: never;
      functionName: "payoutReceived" | "pendingPayout";
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
        }
      );
    }
    return list;
  }, [circleId, memberCount]);

  const { data } = useReadContracts({ contracts });

  const pastWinners: PastWinner[] = useMemo(() => {
    if (!memberSelectedEvents || memberSelectedEvents.length === 0 || !data || memberCount <= 0) return [];

    const payoutBySlot = new Map<number, { received: boolean; pending: boolean }>();
    for (let slot = 0; slot < memberCount; slot++) {
      const baseIdx = slot * 2;
      const received = data[baseIdx]?.result === true;
      const pending = data[baseIdx + 1]?.result === true;
      payoutBySlot.set(slot, { received, pending });
    }

    const result: PastWinner[] = [];
    memberSelectedEvents.forEach((log, index) => {
      const slot = log.args?.slot;
      const shieldedId = log.args?.shieldedId as `0x${string}` | undefined;
      if (slot === undefined || !shieldedId) return;

      const status = payoutBySlot.get(slot);
      if (!status) return;
      if (status.received && !status.pending) {
        result.push({
          roundNumber: index + 1,
          slot,
          shieldedId,
        });
      }
    });
    return result;
  }, [memberSelectedEvents, data, memberCount]);

  return { pastWinners };
}
