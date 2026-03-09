"use client";

import { Card, CardContent } from "@/components/ui/card";
import type { PastWinner } from "@/hooks/usePastWinners";

function truncateShieldedId(id: `0x${string}` | string): string {
  const s = typeof id === "string" ? id : id;
  if (s.length <= 14) return s;
  return `${s.slice(0, 8)}...${s.slice(-6)}`;
}

export interface PastWinnersListProps {
  pastWinners: PastWinner[];
}

export function PastWinnersList({ pastWinners }: PastWinnersListProps) {
  return (
    <Card className="w-full overflow-hidden">
      <CardContent className="p-6 space-y-4">
        <h4 className="text-sm font-semibold">Past winners</h4>
        <ul className="space-y-2">
          {pastWinners.map(({ slot, shieldedId }) => (
            <li
              key={slot}
              className="text-sm font-mono text-muted-foreground"
            >
              {truncateShieldedId(shieldedId)}
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  );
}
