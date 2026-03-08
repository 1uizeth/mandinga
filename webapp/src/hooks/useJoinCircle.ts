"use client";

import { useCallback } from "react";
import {
  useWriteContract,
  useWaitForTransactionReceipt,
  usePublicClient,
  useAccount,
} from "wagmi";
import { baseSepolia } from "wagmi/chains";
import { useQueryClient } from "@tanstack/react-query";
import { SAVINGS_CIRCLE } from "@/lib/contracts";
import SavingsCircleAbi from "@/lib/abi/ISavingsCircle.json";
import { isUserRejection } from "@/lib/errors";

const REFETCH_DELAY_MS = 1500;

/** Base Sepolia per-tx gas cap. */
const MAX_GAS = BigInt(25000000);

function capGas(estimated: bigint, bufferBps = BigInt(1200)): bigint {
  const withBuffer = (estimated * bufferBps) / BigInt(1000);
  return withBuffer > MAX_GAS ? MAX_GAS : withBuffer;
}

export interface UseJoinCircleOptions {
  onSuccess?: () => void | Promise<void>;
}

export function useJoinCircle(options?: UseJoinCircleOptions) {
  const { onSuccess } = options ?? {};
  const queryClient = useQueryClient();
  const publicClient = usePublicClient({ chainId: baseSepolia.id });
  const { address } = useAccount();

  const write = useWriteContract();
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({
    hash: write.data,
  });

  const joinCircle = useCallback(
    async (circleId: bigint) => {
      try {
        const gas = publicClient && address
          ? await publicClient.estimateContractGas({
              address: SAVINGS_CIRCLE,
              abi: SavingsCircleAbi.abi as never,
              functionName: "joinCircle",
              args: [circleId],
              account: address,
            }).catch(() => BigInt(1000000))
          : BigInt(1000000);

        await write.writeContractAsync({
          address: SAVINGS_CIRCLE,
          abi: SavingsCircleAbi.abi as never,
          functionName: "joinCircle",
          args: [circleId],
          gas: capGas(gas),
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
        if (!isUserRejection(err instanceof Error ? err : new Error(String(err)))) {
          throw err;
        }
      }
    },
    [write, onSuccess, queryClient, publicClient, address]
  );

  const activateMinInstallment = useCallback(
    async (circleId: bigint) => {
      try {
        const gas = publicClient && address
          ? await publicClient.estimateContractGas({
              address: SAVINGS_CIRCLE,
              abi: SavingsCircleAbi.abi as never,
              functionName: "activateMinInstallment",
              args: [circleId],
              account: address,
            }).catch(() => BigInt(100000))
          : BigInt(100000);

        await write.writeContractAsync({
          address: SAVINGS_CIRCLE,
          abi: SavingsCircleAbi.abi as never,
          functionName: "activateMinInstallment",
          args: [circleId],
          gas: capGas(gas),
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
        if (!isUserRejection(err instanceof Error ? err : new Error(String(err)))) {
          throw err;
        }
      }
    },
    [write, onSuccess, queryClient, publicClient, address]
  );

  return {
    joinCircle,
    activateMinInstallment,
    isPending: write.isPending || isConfirming,
    error: write.error,
    reset: write.reset,
  };
}
