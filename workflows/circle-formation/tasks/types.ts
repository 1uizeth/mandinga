/** Queued intent from Queue contract (Spec 002 US-006). */
export interface QueuedIntent {
  memberId: `0x${string}`;
  depositPerRound: bigint;
  duration: bigint;
}

/** Kickoff result: largest viable N and selected member IDs. */
export interface KickoffResult {
  viable: boolean;
  n?: number;
  memberIds?: `0x${string}`[];
  queueGroupId?: `0x${string}`;
  depositPerRound?: bigint;
  duration?: bigint;
}

/** Circle formation config (from workflow config). */
export interface CircleFormationConfig {
  schedule: string;
  formationThresholdBps?: number;
  defaultApyBps?: number;
  chainSelectorName?: string;
  queueAddress?: `0x${string}`;
  formationAddress?: `0x${string}`;
  yieldRouterAddress?: `0x${string}`;
  /** Fallback: intents from config (testing). Queue contract not deployed. */
  intents?: Array<{ memberId: string; depositPerRound: number; duration: number }>;
  /** Fallback: HTTP URL returning { intents: [...] }. Same shape as intents. */
  intentsUrl?: string;
}
