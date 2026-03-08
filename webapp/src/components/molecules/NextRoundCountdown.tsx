"use client";

import { useEffect, useState } from "react";

function formatCountdown(ts: number): string {
  const now = Math.floor(Date.now() / 1000);
  const diff = ts - now;
  if (diff <= 0) return "Due";
  const d = Math.floor(diff / 86400);
  const h = Math.floor((diff % 86400) / 3600);
  const m = Math.floor((diff % 3600) / 60);
  const parts: string[] = [];
  if (d > 0) parts.push(`${d}d`);
  if (h > 0) parts.push(`${h}h`);
  if (m > 0 || parts.length === 0) parts.push(`${m}m`);
  return parts.join(" ");
}

export interface NextRoundCountdownProps {
  nextRoundTimestamp: bigint;
  roundNumber?: number;
  className?: string;
}

export function NextRoundCountdown({
  nextRoundTimestamp,
  roundNumber,
  className,
}: NextRoundCountdownProps) {
  const ts = Number(nextRoundTimestamp);
  const [countdown, setCountdown] = useState(() =>
    ts > 0 ? formatCountdown(ts) : "—"
  );

  useEffect(() => {
    if (ts <= 0) return;
    const tick = () => setCountdown(formatCountdown(ts));
    tick();
    const id = setInterval(tick, 60000);
    return () => clearInterval(id);
  }, [ts]);

  const dateStr =
    ts > 0
      ? new Date(ts * 1000).toLocaleDateString(undefined, {
          month: "short",
          day: "numeric",
          year: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        })
      : "—";

  return (
    <div className={className}>
      {roundNumber !== undefined && (
        <p className="text-sm text-muted-foreground">
          Round {roundNumber} · Next round
        </p>
      )}
      <p className="font-mono text-sm font-medium">{dateStr}</p>
      {ts > 0 && (
        <p className="text-xs text-muted-foreground mt-1">{countdown} left</p>
      )}
    </div>
  );
}
