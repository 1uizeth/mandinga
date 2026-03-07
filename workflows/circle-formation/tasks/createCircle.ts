/**
 * Call SavingsCircle.createCircle with config values.
 * Uses runtime.getSecret() for CRE_ETH_PRIVATE_KEY (from secrets.yaml + .env).
 */
import type { Runtime } from "@chainlink/cre-sdk";
import {
  createPublicClient,
  createWalletClient,
  encodeFunctionData,
  http,
  type Address,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { baseSepolia } from "viem/chains";
import { withRetry, alertOnFailure } from "../../lib/errorHandler.js";

const CREATE_CIRCLE_ABI = [
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

const MIN_ROUND_DURATION_SEC = 60;

function getEnv(key: string): string | undefined {
  try {
    const g = typeof globalThis !== "undefined" ? globalThis : ({} as Record<string, unknown>);
    const proc = (g as Record<string, unknown>).process;
    const env = proc && typeof proc === "object" && "env" in proc ? (proc as { env: Record<string, string> }).env : null;
    return env?.[key];
  } catch {
    return undefined;
  }
}

export async function createCircle(
  runtime: Runtime<unknown>,
  savingsCircleAddress: `0x${string}`,
  poolSize: bigint,
  memberCount: number,
  roundDuration: bigint,
  minDepositPerRound: bigint,
  skipReceiptWait = false,
  dryRun = false
): Promise<boolean> {
  if (roundDuration < BigInt(MIN_ROUND_DURATION_SEC)) {
    console.warn("[createCircle] roundDuration < 1 min — skipping");
    return false;
  }

  let pk: string;
  try {
    const secret = runtime.getSecret({ id: "CRE_ETH_PRIVATE_KEY" }).result();
    pk = secret.value;
  } catch {
    console.warn("[createCircle] CRE_ETH_PRIVATE_KEY not found — skipping");
    return false;
  }
  if (!pk) {
    console.warn("[createCircle] CRE_ETH_PRIVATE_KEY empty — skipping");
    return false;
  }

  const data = encodeFunctionData({
    abi: CREATE_CIRCLE_ABI,
    functionName: "createCircle",
    args: [poolSize, memberCount, roundDuration, minDepositPerRound],
  });

  const rpcUrl = "https://base-sepolia-rpc.publicnode.com";

  const account = privateKeyToAccount(
    (pk.startsWith("0x") ? pk : `0x${pk}`) as `0x${string}`
  );

  console.log("account", account.address);
  const publicClient = createPublicClient({
    chain: baseSepolia,
    transport: http(rpcUrl),
  });

  const walletClient = createWalletClient({
    chain: baseSepolia,
    transport: http(rpcUrl),
    account,
  });

  try {
    console.log("savingsCircleAddress", savingsCircleAddress);
    console.log("simulateContract", [
      poolSize,memberCount, roundDuration, minDepositPerRound
    ]);
    console.log("publicClient", publicClient);
    await publicClient.simulateContract({
      address: savingsCircleAddress as Address,
      abi: CREATE_CIRCLE_ABI,
      functionName: "createCircle",
      args: [poolSize, memberCount, roundDuration, minDepositPerRound],
      account,
    });

    console.log("dryRun", dryRun);
    if (dryRun || getEnv("CRE_DRY_RUN") === "1") {
      return true;
    }

    const hash = await withRetry(() =>
      walletClient.sendTransaction({
        to: savingsCircleAddress,
        data,
        account,
      })
    );
    console.log("hash", hash);
    if (skipReceiptWait || getEnv("CRE_SKIP_RECEIPT_WAIT") === "1") {
      return !!hash;
    }
    const receipt = await publicClient.waitForTransactionReceipt({
      hash,
      timeout: 15_000,
      pollingInterval: 1_000,
    });
    return receipt.status === "success";
  } catch (err) {
    alertOnFailure("createCircle", err, {
      savingsCircleAddress,
      poolSize: poolSize.toString(),
      memberCount,
      roundDuration: roundDuration.toString(),
    });
    return false;
  }
}
