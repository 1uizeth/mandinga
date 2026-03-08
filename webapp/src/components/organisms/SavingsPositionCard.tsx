"use client";

import { useState, useRef, useEffect } from "react";
import { useAccount } from "wagmi";
import { useSavingsPosition } from "@/hooks/useSavingsPosition";
import { useDeposit } from "@/hooks/useDeposit";
import { useMockDeposit } from "@/hooks/useMockDeposit";
import { useYieldAccrual } from "@/hooks/useYieldAccrual";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { TransactionModal } from "@/components/organisms/TransactionModal";

const IS_MOCK = process.env.NEXT_PUBLIC_MOCK_DEPOSIT === "true";
const DISPLAY_APY = "4.5%";

function formatDisplayBalance(total: number): string {
  const whole = Math.floor(total);
  const cents = Math.floor((total - whole) * 100).toString().padStart(2, "0");
  return `${whole.toLocaleString()}.${cents}`;
}

interface SavingsPositionCardProps {
  externalDepositOpen?: boolean;
  onExternalDepositClose?: () => void;
}

export function SavingsPositionCard({
  externalDepositOpen,
  onExternalDepositClose,
}: SavingsPositionCardProps) {
  const { isConnected } = useAccount();
  const realPosition = useSavingsPosition();
  const refetchRef = useRef(realPosition.refetch);
  refetchRef.current = realPosition.refetch;

  const [modalOpen, setModalOpen] = useState(false);

  const realDeposit = useDeposit({ onSuccess: () => refetchRef.current?.() });
  const mockDeposit = useMockDeposit();

  const { position, isLoading } = IS_MOCK
    ? {
        position: {
          balance: mockDeposit.balance,
          isActive: mockDeposit.balance > BigInt(0),
          withdrawable: mockDeposit.balance,
          circleObligation: BigInt(0),
        },
        isLoading: false,
      }
    : realPosition;

  const { depositToSavings, isPending, error, txStep, txAmount, resetTxState } =
    IS_MOCK ? mockDeposit : realDeposit;

  const handleClose = () => {
    resetTxState();
    setModalOpen(false);
    onExternalDepositClose?.();
  };

  const isModalOpen = modalOpen || !!externalDepositOpen;

  const balance = position?.balance ?? BigInt(0);
  const hasBalance = balance > BigInt(0);
  const { earned } = useYieldAccrual(balance);

  const balanceFloat = Number(balance) / 1_000_000;
  const totalDisplay = balanceFloat + earned;
  const displayCents = Math.floor(totalDisplay * 100);

  const prevCentsRef = useRef(-1);
  const [flashKey, setFlashKey] = useState(0);

  useEffect(() => {
    if (!hasBalance) {
      prevCentsRef.current = -1;
      return;
    }
    if (prevCentsRef.current === -1) {
      prevCentsRef.current = displayCents;
      return;
    }
    if (displayCents !== prevCentsRef.current) {
      prevCentsRef.current = displayCents;
      setFlashKey((k) => k + 1);
    }
  }, [displayCents, hasBalance]);

  if (isLoading) {
    return (
      <Card className="w-full">
        <CardContent className="p-10 flex flex-col items-center gap-6">
          <Skeleton className="h-3 w-32" />
          <Skeleton className="h-16 w-44" />
          <Skeleton className="h-4 w-40" />
          <Skeleton className="h-11 w-full" />
        </CardContent>
      </Card>
    );
  }

  return (
    <>
      <Card className="w-full">
        <CardContent className="p-10 flex flex-col items-center text-center gap-7">
          <p className="text-xs text-muted-foreground font-medium tracking-widest uppercase">
            Savings Account
          </p>

          <div className="flex flex-col items-center gap-1.5">
            <span
              key={flashKey}
              role={isConnected ? "button" : undefined}
              tabIndex={isConnected ? 0 : undefined}
              aria-label={isConnected ? "Open deposit" : undefined}
              onClick={() => isConnected && setModalOpen(true)}
              onKeyDown={(e) => isConnected && e.key === "Enter" && setModalOpen(true)}
              className={`text-6xl font-semibold tabular-nums leading-none tracking-tight transition-colors select-none ${isConnected ? "cursor-pointer hover:opacity-70" : "cursor-default"} ${!hasBalance ? "text-muted-foreground/40" : ""} ${flashKey > 0 ? "animate-balance-flash" : ""}`}
            >
              {formatDisplayBalance(totalDisplay)}
            </span>
            <span className="text-base text-muted-foreground font-medium">USDC</span>
          </div>

          {/* Yield module */}
          <div className="w-full rounded-xl border border-border bg-muted/40 px-5 py-4 flex flex-col gap-4">

            {earned >= 0.0001 ? (
              <>
                {/* Earned */}
                <div className="flex flex-col gap-1">
                  <span className="text-xs text-muted-foreground">Earned</span>
                  <span className="text-xl font-mono tabular-nums font-semibold text-success">
                    +{earned.toFixed(4)} USDC
                  </span>
                </div>

                <div className="h-px bg-border" />
              </>
            ) : !hasBalance ? (
              <p className="text-xs text-muted-foreground">
                Deposit to start earning. Yield accrues every second.
              </p>
            ) : null}

            {/* APY pill */}
            <div className="flex justify-center">
              <div className="inline-flex items-center gap-2 rounded-full border border-success/30 bg-success/10 px-3 py-1">
                <span
                  className={`inline-block h-2 w-2 rounded-full bg-success shrink-0 ${hasBalance ? "animate-pulse" : ""}`}
                />
                <span className="text-sm font-semibold text-success">{DISPLAY_APY} APY</span>
              </div>
            </div>
          </div>

          <Button
            size="lg"
            className="w-full"
            onClick={() => setModalOpen(true)}
            disabled={isPending || !isConnected}
          >
            {isConnected ? "Deposit" : "Connect Wallet to Deposit"}
          </Button>
        </CardContent>
      </Card>

      <TransactionModal
        open={isModalOpen || txStep !== "idle"}
        onClose={handleClose}
        step={txStep}
        amount={txAmount ?? undefined}
        error={error}
        onRetry={() => txAmount && depositToSavings(txAmount)}
        onConfirm={(amount) => depositToSavings(amount)}
      />
    </>
  );
}
