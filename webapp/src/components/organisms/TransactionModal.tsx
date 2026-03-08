"use client";

import { useEffect, useState } from "react";
import { Check, Loader2, XCircle, ArrowRight, RotateCcw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import { getErrorMessage, isRpcError } from "@/lib/errors";
import type { TxStep } from "@/types/deposit";

export type { TxStep };

export interface TransactionModalProps {
  open: boolean;
  onClose: () => void;
  step: TxStep;
  amount?: string;
  error?: Error | null;
  onRetry?: () => void;
  onConfirm?: (amount: string) => void;
}

function StepRow({
  label,
  status,
}: {
  label: string;
  status: "pending" | "active" | "done";
}) {
  return (
    <div
      className={cn(
        "flex items-center gap-3 py-3 px-4 rounded-lg transition-all duration-300",
        status === "active" && "bg-primary/10 animate-step-pulse",
        status === "done" && "bg-primary/5"
      )}
    >
      <div
        className={cn(
          "flex h-9 w-9 shrink-0 items-center justify-center rounded-full border-2 transition-colors",
          status === "pending" && "border-muted-foreground/30 bg-muted/50",
          status === "active" && "border-primary bg-primary/20",
          status === "done" && "border-primary bg-primary text-primary-foreground"
        )}
      >
        {status === "pending" && (
          <div className="h-2 w-2 rounded-full bg-muted-foreground/50" />
        )}
        {status === "active" && <Loader2 className="h-4 w-4 animate-spin" />}
        {status === "done" && <Check className="h-4 w-4" />}
      </div>
      <span
        className={cn(
          "text-sm font-medium",
          status === "pending" && "text-muted-foreground",
          status === "active" && "text-foreground",
          status === "done" && "text-foreground"
        )}
      >
        {label}
      </span>
    </div>
  );
}

export function TransactionModal({
  open,
  onClose,
  step,
  amount,
  error,
  onRetry,
  onConfirm,
}: TransactionModalProps) {
  const isComplete = step === "success" || step === "error";
  const isInput = step === "idle";
  const [inputAmount, setInputAmount] = useState("");

  useEffect(() => {
    if (!open) setInputAmount("");
  }, [open]);

  useEffect(() => {
    if (open) {
      document.body.style.overflow = "hidden";
    }
    return () => {
      document.body.style.overflow = "";
    };
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape" && (isComplete || isInput)) onClose();
      if (e.key === "Enter" && isComplete) onClose();
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [open, isComplete, isInput, onClose]);

  if (!open) return null;

  if (isInput) {
    const canConfirm = inputAmount !== "" && parseFloat(inputAmount) > 0;
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center">
        <div
          className="absolute inset-0 bg-black/60 backdrop-blur-sm animate-modal-overlay-in"
          onClick={onClose}
          aria-hidden
        />
        <div
          className="relative z-10 w-full max-w-md mx-4 bg-card border border-border rounded-xl shadow-2xl animate-modal-in"
          role="dialog"
          aria-modal="true"
          aria-labelledby="tx-modal-title"
        >
          <div className="p-6">
            <h2
              id="tx-modal-title"
              className="text-lg font-semibold text-foreground mb-1"
            >
              Deposit USDC
            </h2>
            <p className="text-sm text-muted-foreground mb-6">
              Enter the amount you want to deposit to your savings account.
            </p>
            <div className="relative mb-6">
              <Input
                type="number"
                min="0"
                step="0.01"
                placeholder="0.00"
                value={inputAmount}
                onChange={(e) => setInputAmount(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter" && canConfirm) onConfirm?.(inputAmount);
                }}
                className="pr-16 text-lg h-12"
                autoFocus
              />
              <span className="absolute right-3 top-1/2 -translate-y-1/2 text-sm font-medium text-muted-foreground pointer-events-none">
                USDC
              </span>
            </div>
            <div className="flex gap-3">
              <Button variant="outline" className="flex-1" onClick={onClose}>
                Cancel
              </Button>
              <Button
                className="flex-1"
                disabled={!canConfirm}
                onClick={() => {
                  if (canConfirm) onConfirm?.(inputAmount);
                }}
              >
                Confirm
              </Button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  const approveStatus: "pending" | "active" | "done" =
    step === "approve" || step === "approve-confirm"
      ? "active"
      : step === "deposit" ||
          step === "deposit-confirm" ||
          step === "success"
        ? "done"
        : "pending";

  const depositStatus: "pending" | "active" | "done" =
    step === "approve" || step === "approve-confirm"
      ? "pending"
      : step === "deposit" || step === "deposit-confirm"
        ? "active"
        : step === "success"
          ? "done"
          : "pending";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div
        className={cn(
          "absolute inset-0 bg-black/60 backdrop-blur-sm animate-modal-overlay-in",
          !isComplete && "cursor-wait"
        )}
        onClick={() => isComplete && onClose()}
        aria-hidden
      />
      <div
        className="relative z-10 w-full max-w-md mx-4 bg-card border border-border rounded-xl shadow-2xl animate-modal-in"
        role="dialog"
        aria-modal="true"
        aria-labelledby="tx-modal-title"
      >
        <div className="p-6">
          <h2
            id="tx-modal-title"
            className="text-lg font-semibold text-foreground mb-1"
          >
            {step === "error"
              ? "Transaction Failed"
              : step === "success"
                ? "Deposit Complete"
                : "Depositing USDC"}
          </h2>
          <p className="text-sm text-muted-foreground mb-6">
            {step === "error"
              ? getErrorMessage(error)
              : step === "success"
                ? amount
                  ? `${amount} USDC has been deposited to your savings account.`
                  : "Your deposit was successful."
                : amount
                  ? `Depositing ${amount} USDC`
                  : "Confirm the transactions in your wallet."}
          </p>

          {step !== "error" && step !== "success" && (
            <div className="space-y-2">
              <StepRow
                label="Approve USDC spending"
                status={approveStatus}
              />
              <div className="flex justify-center">
                <ArrowRight className="h-4 w-4 text-muted-foreground rotate-90" />
              </div>
              <StepRow
                label="Deposit to savings account"
                status={depositStatus}
              />
            </div>
          )}

          {step === "error" && (
            <div className="flex flex-col gap-3">
              <div className="flex items-center gap-3 py-4 px-4 rounded-lg bg-destructive/10 border border-destructive/20">
                <XCircle className="h-8 w-8 shrink-0 text-destructive" />
                <p className="text-sm text-destructive">
                  {getErrorMessage(error)}
                </p>
              </div>
              {isRpcError(error) && onRetry && (
                <Button
                  variant="outline"
                  className="w-full"
                  onClick={() => {
                    onClose();
                    onRetry();
                  }}
                >
                  <RotateCcw className="h-4 w-4 mr-2" />
                  Retry
                </Button>
              )}
            </div>
          )}

          {step === "success" && (
            <div className="flex items-center gap-3 py-4 px-4 rounded-lg bg-primary/10 border border-primary/20">
              <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground">
                <Check className="h-5 w-5" />
              </div>
              <p className="text-sm font-medium text-foreground">
                Your savings account has been activated.
              </p>
            </div>
          )}

          {isComplete && (
            <Button className="w-full mt-6" onClick={onClose} autoFocus>
              {step === "success" ? "Done" : "Close"}
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}
