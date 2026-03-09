"use client";

import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { usePublicClient, useReadContract } from "wagmi";
import { parseAbiItem } from "viem";
import { SAVINGS_CIRCLE } from "@/lib/contracts";
import SavingsCircleAbi from "@/lib/abi/ISavingsCircle.json";

export interface PendingPayoutWinner {
  winningSlot: number;
  winningShieldedId: `0x${string}`;
}

const MEMBER_SELECTED_EVENT = parseAbiItem(
  "event MemberSelected(uint256 indexed circleId, uint16 slot, bytes32 shieldedId)"
);

/**
 * Returns the current round winner (most recent MemberSelected who hasn't claimed).
 * Uses MemberSelected events to get the latest winner, since multiple slots can have
 * pendingPayout=true when previous winners haven't claimed yet.
 */
export function usePendingPayoutWinner(
  circleId: bigint | undefined,
  memberCount: number
) {
  const publicClient = usePublicClient();

  const { data: latestEvent } = useQuery({
    queryKey: ["memberSelected", circleId?.toString(), SAVINGS_CIRCLE],
    queryFn: async () => {
      if (!publicClient || circleId === undefined) return null;
      const logs = await publicClient.getLogs({
        address: SAVINGS_CIRCLE,
        event: MEMBER_SELECTED_EVENT,
        args: { circleId },
      });
      return logs.length > 0 ? logs[logs.length - 1]! : null;
    },
    enabled: !!publicClient && circleId !== undefined,
  });

  const slotFromEvent = latestEvent?.args?.slot;
  const shieldedIdFromEvent = latestEvent?.args?.shieldedId
    ? ((latestEvent.args.shieldedId as string).toLowerCase() as `0x${string}`)
    : undefined;

  const { data: pendingPayout } = useReadContract({
    address: SAVINGS_CIRCLE,
    abi: SavingsCircleAbi.abi,
    functionName: "pendingPayout",
    args:
      slotFromEvent !== undefined && circleId !== undefined
        ? [circleId, slotFromEvent]
        : undefined,
  });

  const winner: PendingPayoutWinner | null = useMemo(() => {
    if (
      circleId === undefined ||
      memberCount <= 0 ||
      slotFromEvent === undefined ||
      !shieldedIdFromEvent ||
      pendingPayout !== true
    ) {
      return null;
    }
    return {
      winningSlot: slotFromEvent,
      winningShieldedId: shieldedIdFromEvent,
    };
  }, [circleId, memberCount, slotFromEvent, shieldedIdFromEvent, pendingPayout]);

  return { winner };
}
