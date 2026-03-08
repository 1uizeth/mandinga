"use client";

import { useCallback } from "react";
import { useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { useQueryClient } from "@tanstack/react-query";
import { SAVINGS_CIRCLE } from "@/lib/contracts";
import SavingsCircleAbi from "@/lib/abi/ISavingsCircle.json";
import { isUserRejection } from "@/lib/errors";

const REFETCH_DELAY_MS = 1500;

function isGasLimitExceededError(err: unknown): boolean {
  const msg = err instanceof Error ? err.message : String(err);
  return (
    msg.includes("exceeds maximum per-transaction gas limit") ||
    msg.includes("transaction gas") ||
    msg.includes("limit 25000000")
  );
}

export interface UseExecuteRoundOptions {
  onSuccess?: () => void | Promise<void>;
}

export function useExecuteRound(options?: UseExecuteRoundOptions) {
  const { onSuccess } = options ?? {};
  const queryClient = useQueryClient();

  const write = useWriteContract();
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({
    hash: write.data,
  });

  const executeRound = useCallback(
    async (circleId: bigint) => {
      try {
        await write.writeContractAsync({
          address: SAVINGS_CIRCLE,
          abi: SavingsCircleAbi.abi as never,
          functionName: "executeRound",
          args: [circleId],
        });
        await new Promise((r) => setTimeout(r, REFETCH_DELAY_MS));
        await onSuccess?.();
        await queryClient.invalidateQueries({
          predicate: (query) =>
            Array.isArray(query.queryKey) &&
            (query.queryKey[0] === "readContract" ||
              query.queryKey[0] === "readContracts"),
        });
      } catch (err) {
        if (isUserRejection(err instanceof Error ? err : new Error(String(err)))) {
          return;
        }
        if (isGasLimitExceededError(err)) {
          throw new Error(
            "Execute round exceeds Base Sepolia's gas limit (25M). " +
              "Circles with many min-installment members may hit this limit. " +
              "Try a circle with fewer members or without min-installment."
          );
        }
        throw err;
      }
    },
    [write, onSuccess, queryClient]
  );

  return {
    executeRound,
    isPending: write.isPending || isConfirming,
    error: write.error,
    reset: write.reset,
  };
}
