"use client";

import { useState, useCallback } from "react";
import {
  useAccount,
  useWriteContract,
  usePublicClient,
  useReadContract,
} from "wagmi";
import { useQueryClient } from "@tanstack/react-query";
import { parseUnits } from "viem";
import { baseSepolia } from "wagmi/chains";
import { SAVINGS_ACCOUNT, USDC } from "@/lib/contracts";
import SavingsAccountAbi from "@/lib/abi/ISavingsAccount.json";
import Erc20Abi from "@/lib/abi/ERC20.json";
import type { TxStep } from "@/types/deposit";
import { isUserRejection } from "@/lib/errors";

/** Base Sepolia per-tx gas cap. */
const MAX_GAS = BigInt(25000000);

/** Delay after tx confirmation to allow RPC to index new state. */
const REFETCH_DELAY_MS = 1500;

function capGas(estimated: bigint, bufferBps = BigInt(1200)): bigint {
  const withBuffer = (estimated * bufferBps) / BigInt(1000);
  return withBuffer > MAX_GAS ? MAX_GAS : withBuffer;
}

export interface UseDepositOptions {
  onSuccess?: () => void | Promise<void>;
}

export function useDeposit(options?: UseDepositOptions) {
  const { onSuccess } = options ?? {};
  const { address } = useAccount();
  const queryClient = useQueryClient();
  const publicClient = usePublicClient({ chainId: baseSepolia.id });

  const { data: usdcBalance } = useReadContract({
    address: USDC,
    abi: Erc20Abi as never,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  });

  const [txStep, setTxStep] = useState<TxStep>("idle");
  const [txAmount, setTxAmount] = useState<string | null>(null);
  const [txError, setTxError] = useState<Error | null>(null);

  const approveMutation = useWriteContract();
  const depositMutation = useWriteContract();

  const resetTxState = useCallback(() => {
    setTxStep("idle");
    setTxAmount(null);
    setTxError(null);
  }, []);

  const depositToSavings = useCallback(
    async (amountUsdc: string) => {
      if (!address) return;
      setTxStep("approve");
      setTxAmount(amountUsdc);
      setTxError(null);

      const amount = parseUnits(amountUsdc, 6);

      if (usdcBalance !== undefined && usdcBalance < amount) {
        setTxError(
          new Error("Insufficient USDC balance. Please ensure you have enough USDC.")
        );
        setTxStep("error");
        return;
      }

      try {
        const approveGas = publicClient
          ? await publicClient.estimateContractGas({
              address: USDC,
              abi: Erc20Abi as never,
              functionName: "approve",
              args: [SAVINGS_ACCOUNT, amount],
              account: address,
            }).catch(() => BigInt(100000))
          : BigInt(100000);

        setTxStep("approve-confirm");
        const approveHash = await approveMutation.writeContractAsync({
          address: USDC,
          abi: Erc20Abi as never,
          functionName: "approve",
          args: [SAVINGS_ACCOUNT, amount],
          gas: capGas(approveGas),
        });

        if (publicClient) {
          const approveReceipt = await publicClient.waitForTransactionReceipt({
            hash: approveHash,
          });
          if (approveReceipt.status === "reverted") {
            throw new Error("Approve transaction reverted");
          }
        }

        setTxStep("deposit");
        const depositGas = publicClient
          ? await publicClient.estimateContractGas({
              address: SAVINGS_ACCOUNT,
              abi: SavingsAccountAbi.abi as never,
              functionName: "deposit",
              args: [amount],
              account: address,
            }).catch(() => BigInt(800000))
          : BigInt(800000);

        setTxStep("deposit-confirm");
        const depositHash = await depositMutation.writeContractAsync({
          address: SAVINGS_ACCOUNT,
          abi: SavingsAccountAbi.abi as never,
          functionName: "deposit",
          args: [amount],
          gas: capGas(depositGas),
        });

        if (publicClient) {
          const depositReceipt = await publicClient.waitForTransactionReceipt({
            hash: depositHash,
          });
          if (depositReceipt.status === "reverted") {
            throw new Error("Deposit transaction reverted");
          }
        }

        setTxStep("success");

        const delayMs = publicClient ? REFETCH_DELAY_MS : REFETCH_DELAY_MS * 2;
        await new Promise((r) => setTimeout(r, delayMs));
        await onSuccess?.();
        await queryClient.invalidateQueries({
          predicate: (query) =>
            Array.isArray(query.queryKey) &&
            (query.queryKey[0] === "readContract" ||
              (typeof query.queryKey[1] === "object" &&
                query.queryKey[1] != null &&
                "address" in query.queryKey[1] &&
                (query.queryKey[1] as { address?: string }).address ===
                  SAVINGS_ACCOUNT)),
        });
      } catch (err) {
        const error = err instanceof Error ? err : new Error(String(err));
        if (isUserRejection(error)) {
          resetTxState();
          return;
        }
        setTxError(error);
        setTxStep("error");
        await onSuccess?.();
        await queryClient.invalidateQueries({
          predicate: (query) =>
            Array.isArray(query.queryKey) &&
            query.queryKey[0] === "readContract",
        });
      }
    },
    [
      address,
      usdcBalance,
      publicClient,
      approveMutation,
      depositMutation,
      queryClient,
      onSuccess,
      resetTxState,
    ]
  );

  const isPending =
    approveMutation.isPending || depositMutation.isPending;
  const error = approveMutation.error ?? depositMutation.error ?? txError;

  return {
    depositToSavings,
    isPending,
    error,
    txStep,
    txAmount,
    resetTxState,
  };
}
