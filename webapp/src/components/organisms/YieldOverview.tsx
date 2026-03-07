"use client";

import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { TokenAmountDisplay } from "@/components/molecules/TokenAmountDisplay";
import { useCumulativeYield } from "@/hooks/useCumulativeYield";

function YieldOverviewSkeleton() {
  return (
    <Card className="w-full min-h-[160px]">
      <CardHeader>
        <Skeleton className="h-5 w-28" />
      </CardHeader>
      <CardContent>
        <Skeleton className="h-8 w-32 mb-2" />
        <Skeleton className="h-4 w-48" />
      </CardContent>
    </Card>
  );
}

export function YieldOverview() {
  const { cumulativeYieldUsdc, isLoading } = useCumulativeYield();

  if (isLoading) {
    return <YieldOverviewSkeleton />;
  }

  const hasYield = cumulativeYieldUsdc > BigInt(0);

  if (!hasYield) {
    return (
      <Card className="w-full">
        <CardHeader>
          <h3 className="text-lg font-semibold">Yield Earned</h3>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground text-sm">
            No yield yet. Deposit USDC to start earning. Yield accrues as your
            balance grows from the protocol&apos;s yield sources.
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="w-full">
      <CardHeader>
        <h3 className="text-lg font-semibold">Yield Earned</h3>
      </CardHeader>
      <CardContent>
        <p className="text-2xl font-semibold">
          <TokenAmountDisplay amount={cumulativeYieldUsdc} />
        </p>
        <p className="text-sm text-muted-foreground mt-1">
          Cumulative yield since first deposit
        </p>
      </CardContent>
    </Card>
  );
}
