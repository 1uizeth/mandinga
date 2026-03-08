"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { Button } from "@/components/ui/button";
import { Spinner } from "@/components/atoms/Spinner";
import { useJoinCircle } from "@/hooks/useJoinCircle";
import { useSavingsPosition } from "@/hooks/useSavingsPosition";
import type { CircleWithMembers } from "@/hooks/useCircle";

export interface JoinCircleButtonProps {
  circle: CircleWithMembers;
  onSuccess?: () => void;
  className?: string;
}

export function JoinCircleButton({
  circle,
  onSuccess,
  className,
}: JoinCircleButtonProps) {
  const { isConnected } = useAccount();
  const { position } = useSavingsPosition();
  const {
    joinCircle,
    activateMinInstallment,
    isPending,
    error,
  } = useJoinCircle({ onSuccess });

  const [useMinInstallment, setUseMinInstallment] = useState(false);
  const hasMinInstallment = circle.minDepositPerRound > BigInt(0);

  const requiredBalance = useMinInstallment
    ? circle.minDepositPerRound
    : circle.contributionPerMember;
  const hasEnoughBalance =
    position && position.withdrawable >= requiredBalance;

  const handleJoin = async () => {
    if (hasMinInstallment && useMinInstallment) {
      await activateMinInstallment(circle.circleId);
    }
    await joinCircle(circle.circleId);
  };

  if (!isConnected) {
    return (
      <p className="text-sm text-muted-foreground">Connect your wallet to join.</p>
    );
  }

  if (circle.slot >= 0) {
    return (
      <p className="text-sm text-muted-foreground">You are already a member.</p>
    );
  }

  if (circle.status !== 0) {
    return (
      <p className="text-sm text-muted-foreground">
        This circle is no longer accepting new members.
      </p>
    );
  }

  return (
    <div className={className}>
      {hasMinInstallment && (
        <label className="flex items-center gap-2 mb-3 cursor-pointer">
          <input
            type="checkbox"
            checked={useMinInstallment}
            onChange={(e) => setUseMinInstallment(e.target.checked)}
            disabled={isPending}
            className="rounded border-input"
          />
          <span className="text-sm">Use min installment</span>
        </label>
      )}
      <Button
        onClick={handleJoin}
        disabled={isPending || !hasEnoughBalance}
        className="w-full"
      >
        {isPending ? <Spinner size="sm" /> : "Join Circle"}
      </Button>
      {!hasEnoughBalance && position && (
        <p className="text-sm text-destructive mt-2">
          Insufficient balance. Deposit at least{" "}
          {(Number(requiredBalance) / 1e6).toLocaleString()} USDC to your savings
          account first.
        </p>
      )}
      {error && (
        <p className="text-sm text-destructive mt-2">{error.message}</p>
      )}
    </div>
  );
}
