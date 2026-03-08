"use client";

import { useState, useCallback } from "react";
import type { TxStep } from "@/types/deposit";

const STEP_MS = 1200;

export function useMockDeposit() {
  const [txStep, setTxStep] = useState<TxStep>("idle");
  const [txAmount, setTxAmount] = useState<string | null>(null);
  const [balance, setBalance] = useState<bigint>(BigInt(0));

  const resetTxState = useCallback(() => {
    setTxStep("idle");
    setTxAmount(null);
  }, []);

  const depositToSavings = useCallback(async (amount: string) => {
    setTxAmount(amount);
    setTxStep("approve");
    await new Promise((r) => setTimeout(r, STEP_MS));
    setTxStep("approve-confirm");
    await new Promise((r) => setTimeout(r, STEP_MS));
    setTxStep("deposit");
    await new Promise((r) => setTimeout(r, STEP_MS));
    setTxStep("deposit-confirm");
    await new Promise((r) => setTimeout(r, STEP_MS));
    setBalance((prev) => prev + BigInt(Math.round(parseFloat(amount) * 1_000_000)));
    setTxStep("success");
  }, []);

  return {
    depositToSavings,
    isPending: !["idle", "success", "error"].includes(txStep),
    error: null as Error | null,
    txStep,
    txAmount,
    resetTxState,
    balance,
  };
}
