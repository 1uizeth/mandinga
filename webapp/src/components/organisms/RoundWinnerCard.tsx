"use client";

import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Spinner } from "@/components/atoms/Spinner";
import type { PendingPayoutWinner } from "@/hooks/usePendingPayoutWinner";

const RAINBOW_CAT_GIF = "https://media.giphy.com/media/BSx6mzbW1ew7K/giphy.gif";

function truncateShieldedId(id: `0x${string}` | string): string {
  const s = typeof id === "string" ? id : id;
  if (s.length <= 14) return s;
  return `${s.slice(0, 8)}...${s.slice(-6)}`;
}

export interface RoundWinnerCardProps {
  winner: PendingPayoutWinner;
  isCurrentUser: boolean;
  roundNumber?: number;
  onClaim?: () => void;
  isClaimPending?: boolean;
}

export function RoundWinnerCard({
  winner,
  isCurrentUser,
  roundNumber,
  onClaim,
  isClaimPending,
}: RoundWinnerCardProps) {
  const roundLabel =
    roundNumber !== undefined
      ? `Round ${roundNumber} winner`
      : "Round winner";

  return (
    <Card className="w-full overflow-hidden">
      <CardContent className="p-6 space-y-4">
        <h4 className="text-sm font-semibold">
          {isCurrentUser ? `You won round ${roundNumber ?? "—"}!` : roundLabel}
        </h4>
        {isCurrentUser ? (
          <div className="flex flex-col items-center gap-4">
            <img
              src={RAINBOW_CAT_GIF}
              alt="Rainbow cat celebration"
              className="w-48 h-auto rounded-lg"
            />
            <p className="text-sm text-muted-foreground font-mono">
              {truncateShieldedId(winner.winningShieldedId)}
            </p>
            {onClaim && (
              <Button
                onClick={onClaim}
                disabled={isClaimPending}
                className="w-full sm:w-auto"
              >
                {isClaimPending ? (
                  <Spinner size="sm" />
                ) : (
                  "Claim Payout"
                )}
              </Button>
            )}
          </div>
        ) : (
          <p className="text-sm font-mono text-muted-foreground">
            {truncateShieldedId(winner.winningShieldedId)}
          </p>
        )}
      </CardContent>
    </Card>
  );
}
