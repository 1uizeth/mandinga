"use client";

import { useAccount, useReadContract } from "wagmi";
import { SAVINGS_ACCOUNT } from "@/lib/contracts";
import SavingsAccountAbi from "@/lib/abi/ISavingsAccount.json";

export function useShieldedId() {
  const { address } = useAccount();

  const { data: shieldedId, ...rest } = useReadContract({
    address: SAVINGS_ACCOUNT,
    abi: SavingsAccountAbi.abi as never,
    functionName: "computeShieldedId",
    args: address ? [address] : undefined,
  });

  return { shieldedId: shieldedId as `0x${string}` | undefined, ...rest };
}
