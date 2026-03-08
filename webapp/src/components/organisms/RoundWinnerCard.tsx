"use client";

import { Card, CardContent } from "@/components/ui/card";
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
}

export function RoundWinnerCard({ winner, isCurrentUser }: RoundWinnerCardProps) {
  return (
    <Card className="w-full overflow-hidden">
      <CardContent className="p-6 space-y-4">
        <h4 className="text-sm font-semibold">
          {isCurrentUser ? "You won this round!" : "Round winner"}
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
