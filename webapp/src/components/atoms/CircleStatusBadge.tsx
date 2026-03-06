"use client";

import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import type { CircleStatus } from "@/hooks/useUserCircles";

export type CircleStatusBadgeVariant = "ended" | "active" | "joined";

const statusLabels: Record<CircleStatus, string> = {
  0: "Forming",
  1: "Active",
  2: "Ended",
};

const variantByStatus: Record<CircleStatus, CircleStatusBadgeVariant> = {
  0: "joined",
  1: "active",
  2: "ended",
};

const variantStyles: Record<CircleStatusBadgeVariant, string> = {
  ended: "border-muted-foreground/50 bg-muted text-muted-foreground",
  active: "border-green-500/50 bg-green-500/10 text-green-700 dark:text-green-400",
  joined: "border-blue-500/50 bg-blue-500/10 text-blue-700 dark:text-blue-400",
};

export interface CircleStatusBadgeProps {
  status: CircleStatus;
  className?: string;
}

export function CircleStatusBadge({ status, className }: CircleStatusBadgeProps) {
  const variant = variantByStatus[status];
  const label = statusLabels[status];
  return (
    <Badge
      variant="outline"
      className={cn(variantStyles[variant], className)}
    >
      {label}
    </Badge>
  );
}
