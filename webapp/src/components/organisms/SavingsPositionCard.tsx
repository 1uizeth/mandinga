"use client";

import { useSavingsPosition, type SavingsPosition } from "@/hooks/useSavingsPosition";
import { useDeposit } from "@/hooks/useDeposit";
import { TokenAmountDisplay } from "@/components/molecules/TokenAmountDisplay";
import { StatCard } from "@/components/molecules/StatCard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Spinner } from "@/components/atoms/Spinner";
import { TransactionModal } from "@/components/organisms/TransactionModal";
import type { TxStep } from "@/types/deposit";
import { useState, useRef } from "react";

function EmptyState() {
  return (
    <Card>
      <CardContent className="p-8 text-center">
        <p className="text-muted-foreground mb-4">
          No balance yet. Deposit USDC to activate your savings account and start
          earning yield.
        </p>
      </CardContent>
    </Card>
  );
}

function DepositForm({
  onDeposit,
  isPending,
  error,
}: {
  onDeposit: (amount: string) => void | Promise<void>;
  isPending: boolean;
  error: Error | null;
}) {
  const [amount, setAmount] = useState("");

  const handleDeposit = async () => {
    if (!amount || parseFloat(amount) <= 0) return;
    await onDeposit(amount);
    setAmount("");
  };

  return (
    <div className="space-y-4">
      <div className="space-y-2">
        <Label htmlFor="deposit-amount">Amount (USDC)</Label>
        <Input
          id="deposit-amount"
          type="number"
          min="0"
          step="0.01"
          placeholder="0.00"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          disabled={isPending}
        />
      </div>
      <Button onClick={handleDeposit} disabled={isPending || !amount}>
        {isPending ? <Spinner size="sm" /> : "Deposit"}
      </Button>
      {error && (
        <p className="text-sm text-destructive">{error.message}</p>
      )}
    </div>
  );
}

function PositionContent({
  position,
  depositToSavings,
  isPending,
  error,
  txStep,
  txAmount,
  resetTxState,
}: {
  position: SavingsPosition;
  depositToSavings: (amount: string) => Promise<void>;
  isPending: boolean;
  error: Error | null;
  txStep: TxStep;
  txAmount: string | null;
  resetTxState: () => void;
}) {
  const handleRetry = () => {
    if (txAmount) depositToSavings(txAmount);
  };

  return (
    <>
      <Card className="w-full">
        <CardHeader>
          <h3 className="text-lg font-semibold">Savings Account</h3>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="grid gap-4 sm:grid-cols-2">
            <StatCard
              label="Balance"
              value={<TokenAmountDisplay amount={position.balance} />}
            />
            <StatCard
              label="Withdrawable"
              value={<TokenAmountDisplay amount={position.withdrawable} />}
              subValue={
                position.circleObligation > BigInt(0)
                  ? `${position.circleObligation.toString()} locked in circle`
                  : undefined
              }
            />
          </div>
          <DepositForm
            onDeposit={depositToSavings}
            isPending={isPending}
            error={error}
          />
        </CardContent>
      </Card>
      <TransactionModal
        open={txStep !== "idle"}
        onClose={resetTxState}
        step={txStep}
        amount={txAmount ?? undefined}
        error={error}
        onRetry={handleRetry}
      />
    </>
  );
}

export function SavingsPositionCard() {
  const { position, isLoading, refetch } = useSavingsPosition();
  const refetchRef = useRef(refetch);
  refetchRef.current = refetch;

  const {
    depositToSavings,
    isPending,
    error,
    txStep,
    txAmount,
    resetTxState,
  } = useDeposit({
    onSuccess: () => refetchRef.current?.(),
  });

  if (isLoading) {
    return (
      <Card className="w-full">
        <CardHeader>
          <Skeleton className="h-5 w-36" />
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="grid gap-4 sm:grid-cols-2">
            <Card>
              <CardContent className="p-4">
                <Skeleton className="h-4 w-16 mb-2" />
                <Skeleton className="h-7 w-24" />
              </CardContent>
            </Card>
            <Card>
              <CardContent className="p-4">
                <Skeleton className="h-4 w-24 mb-2" />
                <Skeleton className="h-7 w-20" />
              </CardContent>
            </Card>
          </div>
          <div className="space-y-4">
            <Skeleton className="h-4 w-24" />
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-24" />
          </div>
        </CardContent>
      </Card>
    );
  }

  if (!position || !position.isActive) {
    return (
      <>
        <EmptyState />
        <Card>
          <CardHeader>
            <h3 className="text-lg font-semibold">Activate Account</h3>
          </CardHeader>
          <CardContent>
            <DepositForm
              onDeposit={depositToSavings}
              isPending={isPending}
              error={error}
            />
          </CardContent>
        </Card>
        <TransactionModal
          open={txStep !== "idle"}
          onClose={resetTxState}
          step={txStep}
          amount={txAmount ?? undefined}
          error={error}
          onRetry={() => txAmount && depositToSavings(txAmount)}
        />
      </>
    );
  }

  return (
    <PositionContent
      position={position}
      depositToSavings={depositToSavings}
      isPending={isPending}
      error={error}
      txStep={txStep}
      txAmount={txAmount}
      resetTxState={resetTxState}
    />
  );
}
