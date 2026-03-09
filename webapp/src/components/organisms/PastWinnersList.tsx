"use client";

import { Card, CardContent } from "@/components/ui/card";
import type { PastWinner } from "@/hooks/usePastWinners";

const RAINBOW_CAT_GIF = "https://media.giphy.com/media/BSx6mzbW1ew7K/giphy.gif";

function truncateShieldedId(id: `0x${string}` | string): string {
  const s = typeof id === "string" ? id : id;
  if (s.length <= 14) return s;
  return `${s.slice(0, 8)}...${s.slice(-6)}`;
}

export interface PastWinnersListProps {
  pastWinners: PastWinner[];
  currentUserShieldedId?: `0x${string}` | null;
}

export function PastWinnersList({
  pastWinners,
  currentUserShieldedId,
}: PastWinnersListProps) {
  return (
    <Card className="w-full overflow-hidden">
      <CardContent className="p-6 space-y-4">
        <h4 className="text-sm font-semibold">Winners by round</h4>
        <ul className="space-y-4">
          {pastWinners.map(({ roundNumber, slot, shieldedId }) => {
            const isCurrentUser =
              !!currentUserShieldedId &&
              (shieldedId as string).toLowerCase() ===
                (currentUserShieldedId as string).toLowerCase();

            return (
              <li key={`${roundNumber}-${slot}`} className="space-y-2">
                <div className="flex items-center gap-2 text-sm">
                  <span className="font-medium text-muted-foreground">
                    Round {roundNumber}:
                  </span>
                  <span className="font-mono">
                    {truncateShieldedId(shieldedId)}
                    {isCurrentUser && (
                      <span className="ml-2 text-primary font-medium">(you)</span>
                    )}
                  </span>
                </div>
                <img
                  src={RAINBOW_CAT_GIF}
                  alt="Round winner"
                  className="w-32 h-auto rounded-lg"
                />
              </li>
            );
          })}
        </ul>
      </CardContent>
    </Card>
  );
}
