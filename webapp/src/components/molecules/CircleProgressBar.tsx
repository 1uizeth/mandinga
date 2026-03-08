"use client";

import { cn } from "@/lib/utils";

export interface CircleProgressBarProps {
  current: number;
  total: number;
  label?: string;
  /** Optional suffix for the value (e.g. "%" for percentage display) */
  valueSuffix?: string;
  className?: string;
}

export function CircleProgressBar({
  current,
  total,
  label,
  valueSuffix,
  className,
}: CircleProgressBarProps) {
  const pct = total > 0 ? Math.min(100, (current / total) * 100) : 0;
  const valueDisplay = valueSuffix
    ? `${current}${valueSuffix}`
    : `${current}/${total}`;

  return (
    <div className={cn("space-y-1", className)}>
      {label && (
        <div className="flex justify-between text-sm">
          <span className="text-muted-foreground">{label}</span>
          <span className="font-mono">
            {valueDisplay}
          </span>
        </div>
      )}
      <div className="h-2 w-full rounded-full bg-muted overflow-hidden">
        <div
          className="h-full rounded-full bg-primary transition-all duration-300"
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
}
