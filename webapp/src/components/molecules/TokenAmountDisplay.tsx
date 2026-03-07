import { cn } from "@/lib/utils";

export interface TokenAmountDisplayProps {
  amount: bigint;
  decimals?: number;
  symbol?: string;
  className?: string;
}

function formatAmount(amount: bigint, decimals: number): string {
  const divisor = BigInt(10 ** decimals);
  const whole = amount / divisor;
  const frac = amount % divisor;
  const fracStr = frac.toString().padStart(decimals, "0").replace(/0+$/, "") || "0";
  return `${whole.toLocaleString()}.${fracStr}`;
}

export function TokenAmountDisplay({
  amount,
  decimals = 6,
  symbol = "USDC",
  className,
}: TokenAmountDisplayProps) {
  const formatted = formatAmount(amount, decimals);
  return (
    <span className={cn("font-mono tabular-nums", className)}>
      {formatted} {symbol}
    </span>
  );
}
