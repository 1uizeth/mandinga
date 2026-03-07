/**
 * Read queued intents for circle formation.
 *
 * Sources (in order):
 * 1. config.intents — array from config (testing; Queue not deployed)
 * 2. config.intentsUrl — HTTP GET to backend API returning { intents: [...] }
 * 3. Queue contract — getQueuedIntents(depositPerRound, duration) when deployed
 *
 * Until Queue exists, use intents or intentsUrl. See workflow-contracts.md.
 */
import type { QueuedIntent } from "./types.js";

export async function readQueue(
  _runtime: unknown,
  _depositPerRound: bigint,
  _duration: bigint,
  queueAddress?: `0x${string}`,
  config?: {
    intents?: Array<{ memberId: string; depositPerRound: number; duration: number }>;
    intentsUrl?: string;
  }
): Promise<QueuedIntent[]> {
  // 1. Config intents (testing). duration in days, depositPerRound in USDC.
  if (config?.intents?.length) {
    console.log("config.intents", JSON.stringify(config.intents, null, 2));
    return config.intents.map((i) => ({
      memberId: (i.memberId.startsWith("0x") ? i.memberId : `0x${i.memberId}`)
        .padEnd(66, "0")
        .slice(0, 66) as `0x${string}`,
      depositPerRound: BigInt(Math.round(i.depositPerRound * 1e6)),
      duration: BigInt(i.duration * 24 * 3600),
    }));
  }

  // 2. HTTP intentsUrl (backend API)
  if (config?.intentsUrl) {
    const res = await fetch(config.intentsUrl);
    if (!res.ok) return [];
    const json = (await res.json()) as { intents?: typeof config.intents };
    const list = json.intents ?? [];
    return list.map((i) => ({
      memberId: (i.memberId.startsWith("0x") ? i.memberId : `0x${i.memberId}`)
        .padEnd(66, "0")
        .slice(0, 66) as `0x${string}`,
      depositPerRound: BigInt(Math.round(i.depositPerRound * 1e6)),
      duration: BigInt(i.duration * 24 * 3600),
    }));
  }

  // 3. Queue contract (when deployed)
  if (queueAddress) {
    // TODO: evmClient.callContract(Queue.getQueuedIntents(depositPerRound, duration))
    // Queue ABI not available yet.
  }

  return [];
}
