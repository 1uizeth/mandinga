"use client";

import { useEffect } from "react";
import { Users, Clock, ChevronRight, Wallet } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

interface CircleOption {
  id: string;
  label: string;
  members: number;
  contributionUsdc: number;
  poolUsdc: number;
  roundDurationLabel: string;
  openSlots: number;
}

const CIRCLE_OPTIONS: CircleOption[] = [
  {
    id: "starter",
    label: "Starter",
    members: 5,
    contributionUsdc: 50,
    poolUsdc: 250,
    roundDurationLabel: "Weekly",
    openSlots: 3,
  },
  {
    id: "growth",
    label: "Growth",
    members: 5,
    contributionUsdc: 200,
    poolUsdc: 1000,
    roundDurationLabel: "Bi-weekly",
    openSlots: 2,
  },
  {
    id: "premium",
    label: "Premium",
    members: 10,
    contributionUsdc: 500,
    poolUsdc: 5000,
    roundDurationLabel: "Monthly",
    openSlots: 7,
  },
];

function formatUsdc(amount: number): string {
  return amount >= 1000
    ? `${(amount / 1000).toLocaleString(undefined, { maximumFractionDigits: 1 })}k`
    : amount.toLocaleString();
}

function CircleCard({
  circle,
  canJoin,
}: {
  circle: CircleOption;
  canJoin: boolean;
}) {
  return (
    <div
      className={cn(
        "rounded-xl border p-4 flex flex-col gap-3 transition-colors",
        canJoin
          ? "border-border bg-card hover:border-primary/40"
          : "border-border/50 bg-muted/30 opacity-60"
      )}
    >
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wider">
            {circle.label}
          </p>
          <p className="text-2xl font-semibold tabular-nums mt-0.5">
            ${formatUsdc(circle.poolUsdc)}
            <span className="text-sm font-normal text-muted-foreground ml-1">pool</span>
          </p>
        </div>
        <div className="flex flex-col items-end gap-1">
          <span className="text-xs text-muted-foreground">
            {circle.openSlots} open
          </span>
          <div className="flex gap-0.5">
            {Array.from({ length: circle.members }).map((_, i) => (
              <div
                key={i}
                className={cn(
                  "h-1.5 w-1.5 rounded-full",
                  i < circle.members - circle.openSlots
                    ? "bg-primary"
                    : "bg-border"
                )}
              />
            ))}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-2 text-xs">
        <div className="flex flex-col gap-0.5">
          <span className="text-muted-foreground flex items-center gap-1">
            <Wallet className="h-3 w-3" /> Per round
          </span>
          <span className="font-medium">${circle.contributionUsdc}</span>
        </div>
        <div className="flex flex-col gap-0.5">
          <span className="text-muted-foreground flex items-center gap-1">
            <Users className="h-3 w-3" /> Members
          </span>
          <span className="font-medium">{circle.members}</span>
        </div>
        <div className="flex flex-col gap-0.5">
          <span className="text-muted-foreground flex items-center gap-1">
            <Clock className="h-3 w-3" /> Cadence
          </span>
          <span className="font-medium">{circle.roundDurationLabel}</span>
        </div>
      </div>

      <Button
        size="sm"
        variant={canJoin ? "default" : "outline"}
        disabled={!canJoin}
        className="w-full"
      >
        {canJoin ? (
          <>
            Join circle <ChevronRight className="h-3.5 w-3.5 ml-1" />
          </>
        ) : (
          `Requires $${circle.contributionUsdc} balance`
        )}
      </Button>
    </div>
  );
}

export interface JoinCircleModalProps {
  open: boolean;
  onClose: () => void;
  balanceUsdc: number;
  onDepositMore?: () => void;
}

export function JoinCircleModal({
  open,
  onClose,
  balanceUsdc,
  onDepositMore,
}: JoinCircleModalProps) {
  const minRequired = CIRCLE_OPTIONS[0].contributionUsdc;
  const hasEnoughForAny = balanceUsdc >= minRequired;

  const visibleCircles = hasEnoughForAny
    ? CIRCLE_OPTIONS.filter((c) => c.contributionUsdc <= balanceUsdc * 2).slice(0, 3)
    : [];

  const smallestAvailable = CIRCLE_OPTIONS[0];

  useEffect(() => {
    if (!open) return;
    document.body.style.overflow = "hidden";
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handleKey);
    return () => {
      document.body.style.overflow = "";
      window.removeEventListener("keydown", handleKey);
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center">
      <div
        className="absolute inset-0 bg-black/60 backdrop-blur-sm animate-modal-overlay-in"
        onClick={onClose}
        aria-hidden
      />
      <div
        className="relative z-10 w-full sm:max-w-md mx-0 sm:mx-4 bg-card border border-border rounded-t-2xl sm:rounded-xl shadow-2xl animate-modal-in max-h-[90dvh] overflow-y-auto"
        role="dialog"
        aria-modal="true"
        aria-labelledby="join-circle-title"
      >
        {/* Handle for mobile sheet feel */}
        <div className="flex justify-center pt-3 pb-1 sm:hidden">
          <div className="h-1 w-10 rounded-full bg-border" />
        </div>

        <div className="p-6 pt-4 sm:pt-6 flex flex-col gap-5">
          {/* Header */}
          <div>
            <h2 id="join-circle-title" className="text-lg font-semibold text-foreground">
              Join a Savings Circle
            </h2>
            <p className="text-sm text-muted-foreground mt-0.5">
              Pool savings with a group. Each round, one member receives the full pot.
            </p>
          </div>

          {/* Balance pill */}
          <div className="flex items-center gap-2.5 rounded-lg border border-border bg-muted/40 px-4 py-3">
            <div className="flex-1 min-w-0">
              <p className="text-xs text-muted-foreground">Your savings balance</p>
              <p className="text-sm font-semibold tabular-nums">
                ${balanceUsdc.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} USDC
              </p>
            </div>
          </div>

          {/* Circle list or empty state */}
          {hasEnoughForAny ? (
            <div className="flex flex-col gap-3">
              {visibleCircles.map((circle) => (
                <CircleCard
                  key={circle.id}
                  circle={circle}
                  canJoin={balanceUsdc >= circle.contributionUsdc}
                />
              ))}
              {CIRCLE_OPTIONS.some((c) => balanceUsdc < c.contributionUsdc) && (
                <p className="text-xs text-center text-muted-foreground">
                  Deposit more to unlock larger circles.
                </p>
              )}
            </div>
          ) : (
            <div className="flex flex-col items-center text-center gap-4 py-4">
              <div className="flex h-14 w-14 items-center justify-center rounded-full bg-muted">
                <Users className="h-6 w-6 text-muted-foreground" />
              </div>
              <div className="flex flex-col gap-1.5">
                <p className="text-sm font-semibold text-foreground">
                  Not enough balance yet
                </p>
                <p className="text-xs text-muted-foreground leading-relaxed max-w-xs">
                  {CIRCLE_OPTIONS.length} circles available — the smallest requires a{" "}
                  <span className="font-medium text-foreground">
                    ${smallestAvailable.contributionUsdc} USDC
                  </span>{" "}
                  balance. Deposit more to get started.
                </p>
              </div>
              <Button
                size="sm"
                onClick={() => {
                  onClose();
                  onDepositMore?.();
                }}
              >
                Deposit more
              </Button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
