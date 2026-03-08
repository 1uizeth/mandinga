"use client";

import { useMemo } from "react";
import { useReadContracts } from "wagmi";
import { SAVINGS_ACCOUNT } from "@/lib/contracts";
import SavingsAccountAbi from "@/lib/abi/ISavingsAccount.json";

function isFilledSlot(id: `0x${string}` | string): boolean {
  return BigInt(id) !== BigInt(0);
}

export function useCircleMemberPositions(
  members: readonly `0x${string}`[] | undefined
) {
  const contracts = useMemo(() => {
    if (!members) return [];
    return members
      .map((memberId, slot) => ({ memberId, slot }))
      .filter(({ memberId }) => isFilledSlot(memberId))
      .map(({ memberId, slot }) => ({
        address: SAVINGS_ACCOUNT,
        abi: SavingsAccountAbi.abi as never,
        functionName: "getPosition" as const,
        args: [memberId] as [`0x${string}`],
        slot,
      }));
  }, [members]);

  const { data } = useReadContracts({ contracts });

  const memberBalances = useMemo(() => {
    const map = new Map<number, bigint>();
    if (!data) return map;
    contracts.forEach((contract, i) => {
      const result = data[i]?.result;
      if (result) {
        const pos = result as { balance: bigint };
        map.set(contract.slot, BigInt(pos.balance));
      }
    });
    return map;
  }, [data, contracts]);

  return { memberBalances };
}
