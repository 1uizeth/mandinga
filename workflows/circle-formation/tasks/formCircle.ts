/**
 * Form circle: call SavingsCircle.createCircle with params derived from kickoff.
 * Uses ABI from workflows/contracts/abi/SavingsCircle.json.
 * FR-004: withRetry + alertOnFailure.
 */
import { createPublicClient, createWalletClient, encodeFunctionData, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { baseSepolia } from "viem/chains";
import type { KickoffResult } from "./types.js";
import { withRetry, alertOnFailure } from "../../lib/errorHandler.js";

const SAVINGS_CIRCLE_ABI = [
  {
    type: "function",
    name: "createCircle",
    inputs: [
      { name: "poolSize", type: "uint256", internalType: "uint256" },
      { name: "memberCount", type: "uint16", internalType: "uint16" },
      { name: "roundDuration", type: "uint256", internalType: "uint256" },
      { name: "minDepositPerRound", type: "uint256", internalType: "uint256" },
    ],
    outputs: [{ name: "circleId", type: "uint256", internalType: "uint256" }],
    stateMutability: "nonpayable",
  },
] as const;

const MIN_ROUND_DURATION_SEC = 60; // SavingsCircle.MIN_ROUND_DURATION = 1 minutes

export async function formCircle(
  _runtime: unknown,
  savingsCircleAddress: `0x${string}` | undefined,
  kickoff: KickoffResult
): Promise<boolean> {
  if (!kickoff.viable || kickoff.n == null || !savingsCircleAddress) {
    return false;
  }

  const depositPerRound = kickoff.depositPerRound;
  const duration = kickoff.duration;
  if (depositPerRound == null || duration == null) {
    console.warn("[formCircle] depositPerRound/duration not in kickoff — cannot form");
    return false;
  }

  const pk = process.env.CRE_ETH_PRIVATE_KEY;
  if (!pk) {
    console.warn("[formCircle] CRE_ETH_PRIVATE_KEY not set — skipping on-chain submit");
    return false;
  }

  const n = kickoff.n;
  const poolSize = depositPerRound * BigInt(n);
  const roundDuration = duration / BigInt(n);
  if (roundDuration < BigInt(MIN_ROUND_DURATION_SEC)) {
    console.warn("[formCircle] roundDuration < 1 min — skipping");
    return false;
  }
  const minDepositPerRound = 0n;

  const data = encodeFunctionData({
    abi: SAVINGS_CIRCLE_ABI,
    functionName: "createCircle",
    args: [poolSize, n, roundDuration, minDepositPerRound],
  });

  const rpcUrl =
    process.env.RPC_ETHEREUM_TESTNET_SEPOLIA_BASE_1 ??
    "https://base-sepolia-rpc.publicnode.com";
  const publicClient = createPublicClient({
    chain: baseSepolia,
    transport: http(rpcUrl),
  });

  const hexKey = pk.startsWith("0x") ? pk : (`0x${pk}` as `0x${string}`);
  const account = privateKeyToAccount(`0x${hexKey}`);
  const walletClient = createWalletClient({
    chain: baseSepolia,
    transport: http(rpcUrl),
    account,
  });

  try {
    const hash = await withRetry(async () => {
      return walletClient.sendTransaction({
        to: savingsCircleAddress,
        data,
        account,
      });
    });

    if (hash) {
      const receipt = await publicClient.waitForTransactionReceipt({ hash });
      return receipt.status === "success";
    }
    return false;
  } catch (err) {
    alertOnFailure("formCircle", err, {
      savingsCircleAddress,
      poolSize: poolSize.toString(),
      memberCount: n,
      roundDuration: roundDuration.toString(),
    });
    return false;
  }
}
