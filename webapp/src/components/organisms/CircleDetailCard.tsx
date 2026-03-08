"use client";

import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { TokenAmountDisplay } from "@/components/molecules/TokenAmountDisplay";
import type { CircleWithMembers } from "@/hooks/useCircle";

export interface CircleDetailCardProps {
  circle: CircleWithMembers;
}

function formatRoundDuration(seconds: bigint): string {
  const s = Number(seconds);
  if (s >= 86400 * 30) return `${Math.round(s / (86400 * 30))} months`;
  if (s >= 86400) return `${Math.round(s / 86400)} days`;
  if (s >= 3600) return `${Math.round(s / 3600)} hours`;
  return `${Math.round(s / 60)} minutes`;
}

export function CircleDetailCard({ circle }: CircleDetailCardProps) {
  const roundLabel = formatRoundDuration(circle.roundDuration);
  const installmentLabel = `Paid ${(Number(circle.contributionPerMember) / 1e6).toLocaleString()} USDC per round for ${circle.memberCount} rounds`;

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <h3 className="text-lg font-semibold">Circle #{circle.circleId.toString()}</h3>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid gap-3 text-sm">
          <div className="flex justify-between">
            <span className="text-muted-foreground">Pool size</span>
            <TokenAmountDisplay amount={circle.poolSize} />
          </div>
          <div className="flex justify-between">
            <span className="text-muted-foreground">Per round</span>
            <TokenAmountDisplay amount={circle.contributionPerMember} />
          </div>
          <div className="flex justify-between">
            <span className="text-muted-foreground">Members</span>
            <span>
              {circle.filledSlots}/{circle.memberCount} slots
            </span>
          </div>
          <div className="flex justify-between">
            <span className="text-muted-foreground">Round duration</span>
            <span>{roundLabel}</span>
          </div>
        </div>
        <p className="text-sm text-muted-foreground font-medium">
          {installmentLabel}
        </p>
      </CardContent>
    </Card>
  );
}
