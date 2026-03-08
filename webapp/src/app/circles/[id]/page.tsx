"use client";

import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { CircleStatusBadge } from "@/components/atoms/CircleStatusBadge";
import { CircleDetailCard } from "@/components/organisms/CircleDetailCard";
import { CircleProgressBar } from "@/components/molecules/CircleProgressBar";
import { NextRoundCountdown } from "@/components/molecules/NextRoundCountdown";
import { CircleMembersList } from "@/components/organisms/CircleMembersList";
import { JoinCircleButton } from "@/components/organisms/JoinCircleButton";
import { RoundWinnerCard } from "@/components/organisms/RoundWinnerCard";
import { TransactionModal } from "@/components/organisms/TransactionModal";
import { useCircle } from "@/hooks/useCircle";
import { useShieldedId } from "@/hooks/useShieldedId";
import { useCircleMemberPositions } from "@/hooks/useCircleMemberPositions";
import { usePendingPayoutWinner } from "@/hooks/usePendingPayoutWinner";
import { useSavingsPosition } from "@/hooks/useSavingsPosition";
import { useDeposit } from "@/hooks/useDeposit";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Spinner } from "@/components/atoms/Spinner";
import { Skeleton } from "@/components/ui/skeleton";
import { useState, useEffect } from "react";

export default function CircleDetailPage() {
  const params = useParams();
  const router = useRouter();
  const circleId = params.id as string;
  const { circle, isLoading } = useCircle(circleId);
  const { shieldedId } = useShieldedId();
  const { memberBalances } = useCircleMemberPositions(circle?.members);
  const { winner } = usePendingPayoutWinner(
    circle ? BigInt(circle.circleId) : undefined,
    circle?.memberCount ?? 0
  );
  const { position } = useSavingsPosition();
  const {
    depositToSavings,
    isPending: depositPending,
    txStep,
    txAmount,
    resetTxState,
    error: depositError,
  } = useDeposit({
    onSuccess: () => router.refresh(),
  });
  const [depositAmount, setDepositAmount] = useState("");
  const [nowSec, setNowSec] = useState(() => Math.floor(Date.now() / 1000));

  useEffect(() => {
    const id = setInterval(() => setNowSec(Math.floor(Date.now() / 1000)), 60000);
    return () => clearInterval(id);
  }, []);

  // Prefill deposit with exact installment when deposit card is shown
  const shouldPrefillDeposit = !!(
    circle &&
    circle.status === 1 &&
    circle.slot >= 0 &&
    circle.contributionPerMember
  );
  useEffect(() => {
    if (shouldPrefillDeposit && circle && !depositAmount) {
      const installment = (Number(circle.contributionPerMember) / 1e6).toFixed(2);
      setDepositAmount(installment);
    }
  }, [shouldPrefillDeposit, circle, depositAmount]);

  if (isLoading) {
    return (
      <div className="flex flex-col items-center p-4 md:p-6 max-w-4xl mx-auto">
        <Skeleton className="h-8 w-48 mb-4" />
        <Skeleton className="h-64 w-full" />
      </div>
    );
  }

  if (!circle) {
    return (
      <div className="flex flex-col items-center p-4 md:p-6 max-w-4xl mx-auto">
        <p className="text-muted-foreground">Circle not found.</p>
        <Link href="/circles" className="mt-4 text-sm underline">
          Back to circles
        </Link>
      </div>
    );
  }

  const isMember = circle.slot >= 0;
  const isForming = circle.status === 0;
  const isActive = circle.status === 1;
  const nextTs = Number(circle.nextRoundTimestamp);
  const roundIsDue = nextTs > 0 && nowSec >= nextTs;
  const balanceBelowObligation =
    position && position.balance < position.circleObligation;
  const needsDeposit =
    isMember &&
    isActive &&
    (balanceBelowObligation || roundIsDue);

  const progressCurrent = isForming ? circle.filledSlots : circle.roundsCompleted;
  const progressTotal = circle.memberCount;
  const progressLabel = isForming ? "Formation" : "Payouts";

  const roundNumber = isActive ? circle.roundsCompleted + 1 : undefined;

  // Time-based progress of the current round (0–100%)
  const roundDurationSec = Number(circle.roundDuration);
  const roundStartSec = nextTs > 0 ? nextTs - roundDurationSec : 0;
  const roundElapsedSec = roundStartSec > 0 ? Math.max(0, nowSec - roundStartSec) : 0;
  const roundProgressPct =
    roundDurationSec > 0 && isActive
      ? Math.min(100, (roundElapsedSec / roundDurationSec) * 100)
      : 0;

  const membersPaidCount =
    isActive && memberBalances && circle.contributionPerMember
      ? Array.from(memberBalances.entries()).filter(
          ([, balance]) => balance >= circle.contributionPerMember
        ).length
      : 0;

  const isCurrentUserWinner =
    !!winner &&
    !!shieldedId &&
    (winner.winningShieldedId as string).toLowerCase() ===
      (shieldedId as string).toLowerCase();

  function formatRoundDuration(seconds: bigint): string {
    const s = Number(seconds);
    if (s >= 86400 * 30) return `${Math.round(s / (86400 * 30))} months`;
    if (s >= 86400) return `${Math.round(s / 86400)} days`;
    if (s >= 3600) return `${Math.round(s / 3600)} hours`;
    return `${Math.round(s / 60)} minutes`;
  }

  return (
    <div className="flex flex-col items-center p-4 md:p-6 max-w-4xl mx-auto space-y-6">
      <div className="w-full flex items-center justify-between">
        <Link href="/circles" className="text-sm text-muted-foreground hover:underline">
          ← Back to circles
        </Link>
        <CircleStatusBadge status={circle.status} />
      </div>

      <CircleDetailCard circle={circle} />

      <Card className="w-full">
        <CardContent className="p-6 space-y-4">
          <h4 className="text-sm font-semibold">
            {isForming ? "Formation progress" : "Payout progress"}
          </h4>
          <CircleProgressBar
            current={progressCurrent}
            total={progressTotal}
            label={progressLabel}
          />
          {isActive && (
            <>
              <p className="text-sm text-muted-foreground">
                Installment: {(Number(circle.contributionPerMember) / 1e6).toLocaleString()} USDC per round
              </p>
              <p className="text-sm font-medium">
                {membersPaidCount}/{circle.memberCount} paid
                {membersPaidCount < circle.memberCount && (
                  <span className="text-muted-foreground font-normal">
                    {" "}({circle.memberCount - membersPaidCount} missing)
                  </span>
                )}
              </p>
              <p className="text-sm text-muted-foreground">
                Round duration: {formatRoundDuration(circle.roundDuration)}
              </p>
              <CircleProgressBar
                current={Math.round(roundProgressPct)}
                total={100}
                label="Current round"
                valueSuffix="%"
              />
              <NextRoundCountdown
                nextRoundTimestamp={circle.nextRoundTimestamp}
                roundNumber={roundNumber}
              />
            </>
          )}
        </CardContent>
      </Card>

      {winner && (
        <RoundWinnerCard
          winner={winner}
          isCurrentUser={isCurrentUserWinner}
        />
      )}

      {isForming && (
        <Card className="w-full">
          <CardContent className="p-6">
            <h4 className="text-sm font-semibold mb-4">Join this circle</h4>
            <JoinCircleButton
              circle={circle}
              onSuccess={() => router.refresh()}
            />
          </CardContent>
        </Card>
      )}

      {isActive && needsDeposit && (
        <Card className="w-full">
          <CardContent className="p-6">
            <h4 className="text-sm font-semibold mb-4">
              {balanceBelowObligation
                ? "Deposit to meet obligation"
                : "Deposit your installment"}
            </h4>
            <p className="text-sm text-muted-foreground mb-4">
              {balanceBelowObligation
                ? "Your balance is below your circle obligation. Deposit USDC to your savings account to continue."
                : "Round is due — deposit your installment to participate."}
            </p>
            <div className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="deposit-amount">Amount (USDC)</Label>
                <Input
                  id="deposit-amount"
                  type="number"
                  min="0"
                  step="0.01"
                  placeholder="0.00"
                  value={depositAmount}
                  onChange={(e) => setDepositAmount(e.target.value)}
                  disabled={depositPending}
                />
              </div>
              <Button
                onClick={() => depositToSavings(depositAmount)}
                disabled={depositPending || !depositAmount}
              >
                {depositPending ? <Spinner size="sm" /> : "Deposit"}
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      <Card className="w-full">
        <CardContent className="p-6">
          <CircleMembersList
            members={circle.members}
            memberBalances={memberBalances}
            contributionPerMember={isActive ? circle.contributionPerMember : undefined}
            currentUserSlot={circle.slot}
          />
        </CardContent>
      </Card>

      <TransactionModal
        open={txStep !== "idle"}
        onClose={resetTxState}
        step={txStep}
        amount={txAmount ?? undefined}
        error={depositError}
        onRetry={txAmount ? () => depositToSavings(txAmount) : undefined}
      />
    </div>
  );
}
