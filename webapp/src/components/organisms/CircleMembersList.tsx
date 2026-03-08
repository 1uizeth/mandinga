"use client";

import { MemberAvatar } from "@/components/atoms/MemberAvatar";
import { TokenAmountDisplay } from "@/components/molecules/TokenAmountDisplay";

function truncateShieldedId(id: `0x${string}` | string): string {
  const s = typeof id === "string" ? id : id;
  if (s.length <= 14) return s;
  return `${s.slice(0, 8)}...${s.slice(-6)}`;
}

export interface CircleMembersListProps {
  members: readonly `0x${string}`[];
  memberBalances?: Map<number, bigint>;
  /** Obligation per member (contributionPerMember). Used to show Paid/Pending badge. */
  contributionPerMember?: bigint;
  /** Slot index of the current user (-1 if not a member). Used to highlight the user's row. */
  currentUserSlot?: number;
  maxVisible?: number;
  className?: string;
}

function isFilledSlot(id: `0x${string}` | string): boolean {
  return BigInt(id) !== BigInt(0);
}

export function CircleMembersList({
  members,
  memberBalances,
  contributionPerMember,
  currentUserSlot,
  maxVisible = 24,
  className,
}: CircleMembersListProps) {
  const filled = members.filter(isFilledSlot);
  const visible = filled.slice(0, maxVisible);
  const remaining = filled.length - maxVisible;

  return (
    <div className={className}>
      <h4 className="text-sm font-semibold mb-3">Members</h4>
      <ul className="space-y-2">
        {visible.map((memberId, i) => {
          const slot = members.indexOf(memberId);
          const balance = memberBalances?.get(slot);
          const hasPaid =
            contributionPerMember !== undefined &&
            balance !== undefined &&
            balance >= contributionPerMember;
          const isCurrentUser =
            currentUserSlot !== undefined && currentUserSlot >= 0 && slot === currentUserSlot;
          return (
            <li
              key={`${memberId}-${i}`}
              className={`flex items-center gap-3 text-sm rounded-lg px-3 py-2 -mx-3 ${
                isCurrentUser ? "bg-primary/10 ring-1 ring-primary/20" : ""
              }`}
            >
              <MemberAvatar shieldedId={memberId} diameter={28} />
              <span className="font-mono text-muted-foreground">
                {truncateShieldedId(memberId)}
              </span>
              {isCurrentUser && (
                <span className="text-xs font-medium text-primary">You</span>
              )}
              {contributionPerMember !== undefined && balance !== undefined && (
                <span
                  className={`text-xs font-medium ${
                    hasPaid ? "text-green-600 dark:text-green-400" : "text-amber-600 dark:text-amber-400"
                  }`}
                >
                  {hasPaid ? "Paid" : "Pending"}
                </span>
              )}
              {balance !== undefined && (
                <TokenAmountDisplay
                  amount={balance}
                  className="ml-auto text-muted-foreground"
                />
              )}
            </li>
          );
        })}
        {remaining > 0 && (
          <li className="text-sm text-muted-foreground pl-9">
            + {remaining} more members
          </li>
        )}
      </ul>
    </div>
  );
}
