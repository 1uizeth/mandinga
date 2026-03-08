"use client";

import { useMemo, useState } from "react";
import { useAccount } from "wagmi";
import { CircleTemplate } from "@/components/templates/CircleTemplate";
import { CircleStatusPanel } from "@/components/organisms/CircleStatusPanel";
import { useUserCircles, type UserCircle, type CircleStatus } from "@/hooks/useUserCircles";
import { CirclesSkeleton } from "@/components/organisms/CirclesSkeleton";
import { Label } from "@/components/ui/label";

type SortBy = "circleId" | "nextRound" | "status";
type StatusFilter = "all" | "0" | "1" | "2";

function filterAndSortCircles(
  circles: UserCircle[],
  sortBy: SortBy,
  statusFilter: StatusFilter
): UserCircle[] {
  let filtered = circles;
  if (statusFilter !== "all") {
    const statusNum = Number(statusFilter) as CircleStatus;
    filtered = circles.filter((c) => c.status === statusNum);
  }
  return [...filtered].sort((a, b) => {
    switch (sortBy) {
      case "circleId":
        return Number(a.circleId - b.circleId);
      case "nextRound":
        return Number(a.nextRoundTimestamp - b.nextRoundTimestamp);
      case "status":
        return a.status - b.status;
      default:
        return 0;
    }
  });
}

function CirclesContent({
  sortBy,
  statusFilter,
}: {
  sortBy: SortBy;
  statusFilter: StatusFilter;
}) {
  const { circles, isLoading } = useUserCircles();

  const sortedCircles = useMemo(
    () => filterAndSortCircles(circles, sortBy, statusFilter),
    [circles, sortBy, statusFilter]
  );

  if (isLoading) {
    return <CirclesSkeleton />;
  }

  if (circles.length === 0) {
    return (
      <div className="col-span-full rounded-lg border border-dashed p-8 text-center">
        <p className="text-muted-foreground mb-2">No circles yet.</p>
        <p className="text-sm text-muted-foreground">
          Create a circle or wait for others to create one.
        </p>
      </div>
    );
  }

  return (
    <>
      {sortedCircles.map((circle) => (
        <CircleStatusPanel key={circle.circleId.toString()} circle={circle} />
      ))}
    </>
  );
}

function CirclesFilters({
  sortBy,
  onSortBy,
  statusFilter,
  onStatusFilter,
}: {
  sortBy: SortBy;
  onSortBy: (v: SortBy) => void;
  statusFilter: StatusFilter;
  onStatusFilter: (v: StatusFilter) => void;
}) {
  return (
    <div className="flex flex-wrap gap-4">
      <div className="flex items-center gap-2">
        <Label htmlFor="sort-by" className="text-sm text-muted-foreground">
          Sort by
        </Label>
        <select
          id="sort-by"
          value={sortBy}
          onChange={(e) => onSortBy(e.target.value as SortBy)}
          className="h-9 w-[140px] rounded-md border border-input bg-background px-3 py-1 text-sm ring-offset-background focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
        >
          <option value="circleId">Circle ID</option>
          <option value="nextRound">Next round</option>
          <option value="status">Status</option>
        </select>
      </div>
      <div className="flex items-center gap-2">
        <Label htmlFor="status-filter" className="text-sm text-muted-foreground">
          Status
        </Label>
        <select
          id="status-filter"
          value={statusFilter}
          onChange={(e) => onStatusFilter(e.target.value as StatusFilter)}
          className="h-9 w-[140px] rounded-md border border-input bg-background px-3 py-1 text-sm ring-offset-background focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
        >
          <option value="all">All</option>
          <option value="0">Forming</option>
          <option value="1">Active</option>
          <option value="2">Ended</option>
        </select>
      </div>
    </div>
  );
}

export default function CirclesPage() {
  const { isConnected } = useAccount();
  const [sortBy, setSortBy] = useState<SortBy>("circleId");
  const [statusFilter, setStatusFilter] = useState<StatusFilter>("all");

  if (!isConnected) {
    return (
      <CircleTemplate
        cardGrid={
          <p className="text-muted-foreground col-span-full">
            Connect your wallet to view your circles.
          </p>
        }
      />
    );
  }

  return (
    <CircleTemplate
      filters={
        <CirclesFilters
          sortBy={sortBy}
          onSortBy={setSortBy}
          statusFilter={statusFilter}
          onStatusFilter={setStatusFilter}
        />
      }
      cardGrid={
        <CirclesContent sortBy={sortBy} statusFilter={statusFilter} />
      }
    />
  );
}
