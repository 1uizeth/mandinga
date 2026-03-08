"use client";

import { useState, useEffect, useRef } from "react";

const APY = 0.045;

export interface YieldAccrual {
  earned: number;   // USDC earned since balance detected
  perDay: number;   // projected USDC per day
  perMonth: number; // projected USDC per month
  perYear: number;  // projected USDC per year
}

export function useYieldAccrual(balance: bigint): YieldAccrual {
  const startRef = useRef<number | null>(null);
  const [seconds, setSeconds] = useState(0);

  useEffect(() => {
    if (balance <= BigInt(0)) {
      startRef.current = null;
      setSeconds(0);
      return;
    }
    if (startRef.current === null) {
      startRef.current = Date.now();
    }
    const interval = setInterval(() => {
      setSeconds(Math.floor((Date.now() - startRef.current!) / 1000));
    }, 1000);
    return () => clearInterval(interval);
  }, [balance]);

  const balanceFloat = Number(balance) / 1_000_000;
  const perSecond = (balanceFloat * APY) / 365 / 86400;

  return {
    earned: perSecond * seconds,
    perDay: (balanceFloat * APY) / 365,
    perMonth: (balanceFloat * APY) / 12,
    perYear: balanceFloat * APY,
  };
}
