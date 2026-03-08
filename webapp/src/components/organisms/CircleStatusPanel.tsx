"use client";

import Link from "next/link";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { CircleStatusBadge } from "@/components/atoms/CircleStatusBadge";
import { TokenAmountDisplay } from "@/components/molecules/TokenAmountDisplay";
import type { UserCircle } from "@/hooks/useUserCircles";

export interface CircleStatusPanelProps {
  circle: UserCircle;
}

function formatNextRound(nextRoundTimestamp: bigint): string {
  const ts = Number(nextRoundTimestamp);
  if (ts === 0) return "—";
  const date = new Date(ts * 1000);
  return date.toLocaleString(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export function CircleStatusPanel({ circle }: CircleStatusPanelProps) {
  const nextRoundDate = formatNextRound(circle.nextRoundTimestamp);
  const detailHref = `/circles/${circle.circleId.toString()}`;

  const isMember = circle.slot >= 0;
  const isForming = circle.status === 0;
  const showJoin = !isMember && isForming;
  const showView = isMember || (!isMember && circle.status === 1);

  return (
    <Card className="w-full min-h-[220px] flex flex-col">
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <h3 className="text-lg font-semibold">Circle #{circle.circleId.toString()}</h3>
        <CircleStatusBadge status={circle.status} />
      </CardHeader>
      <CardContent className="space-y-2 flex-1 flex flex-col">
        <div className="grid gap-2 text-sm">
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
              {circle.filledSlots}/{circle.memberCount}
            </span>
          </div>
          <div className="flex justify-between">
            <span className="text-muted-foreground">Next round</span>
            <span className="font-mono text-xs">{nextRoundDate}</span>
          </div>
        </div>
        <div className="mt-auto pt-4">
          {showJoin && (
            <Link href={detailHref}>
              <Button className="w-full">Join</Button>
            </Link>
          )}
          {showView && !showJoin && (
            <Link href={detailHref}>
              <Button variant="outline" className="w-full">
                View
              </Button>
            </Link>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
