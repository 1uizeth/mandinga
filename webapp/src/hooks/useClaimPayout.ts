"use client";

import { useCallback } from "react";
import { useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { useQueryClient } from "@tanstack/react-query";
import { SAVINGS_CIRCLE } from "@/lib/contracts";
import SavingsCircleAbi from "@/lib/abi/ISavingsCircle.json";
import { isUserRejection } from "@/lib/errors";

const REFETCH_DELAY_MS = 1500;

export interface UseClaimPayoutOptions {
  onSuccess?: () => void | Promise<void>;
}

export function useClaimPayout(options?: UseClaimPayoutOptions) {
  const { onSuccess } = options ?? {};
  const queryClient = useQueryClient();

  const write = useWriteContract();
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({
    hash: write.data,
  });

  const claimPayout = useCallback(
    async (circleId: bigint, slot: number) => {
      try {
        await write.writeContractAsync({
          address: SAVINGS_CIRCLE,
          abi: SavingsCircleAbi.abi as never,
          functionName: "claimPayout",
          args: [circleId, slot],
        });
        await new Promise((r) => setTimeout(r, REFETCH_DELAY_MS));
        await onSuccess?.();
        await queryClient.invalidateQueries({
          predicate: (query) =>
            Array.isArray(query.queryKey) &&
            (query.queryKey[0] === "readContract" ||
              query.queryKey[0] === "readContracts" ||
              query.queryKey[0] === "memberSelected"),
        });
      } catch (err) {
        if (isUserRejection(err instanceof Error ? err : new Error(String(err)))) {
          return;
        }
        throw err;
      }
    },
    [write, onSuccess, queryClient]
  );

  return {
    claimPayout,
    isPending: write.isPending || isConfirming,
    error: write.error,
    reset: write.reset,
  };
}
