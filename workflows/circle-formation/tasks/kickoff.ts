/**
 * Kickoff algorithm (Spec 002 US-006 AC-006-2, AC-006-3).
 * Evaluates candidate N from queue depth down; selects largest viable N
 * where share of positions beating solo saving >= formation threshold (default 70%).
 */
import type { QueuedIntent, KickoffResult } from "./types.js";

const MIN_MEMBERS = 2;
const DEFAULT_FORMATION_THRESHOLD_BPS = 7000; // 70%

/**
 * Yield advantage for position k in circle of N.
 * Circle: position k receives full pool at round k, earns yield for (N-k) rounds.
 * Solo: saves incrementally — deposit i at round i, held for (k-i) rounds.
 * Solo yield = sum over i=1..k of depositPerRound * apy * ((k-i) * roundLength / year).
 * Position k beats solo if circle yield > solo yield.
 */
function positionBeatsSolo(
  k: number,
  n: number,
  depositPerRound: bigint,
  roundLengthSeconds: number,
  apyBps: number
): boolean {
  if (n < 2 || k < 1 || k > n) return false;
  const poolSize = Number(depositPerRound) * n;
  const roundsHeld = n - k;
  const secondsHeld = roundsHeld * roundLengthSeconds;
  const circleYield = poolSize * (apyBps / 10000) * (secondsHeld / (365 * 24 * 3600));

  // Solo: deposit i at round i, held for (k-i) rounds → sum (k-i) for i=1..k = k(k-1)/2
  const roundsWeighted = (k * (k - 1)) / 2;
  const soloYield =
    Number(depositPerRound) *
    (apyBps / 10000) *
    (roundsWeighted * roundLengthSeconds) /
    (365 * 24 * 3600);

  return circleYield > soloYield;
}

/**
 * Run kickoff: find largest viable N.
 */
export function runKickoff(
  intents: QueuedIntent[],
  apyBps: number,
  formationThresholdBps: number = DEFAULT_FORMATION_THRESHOLD_BPS
): KickoffResult {
  console.log("intents.length", intents.length);
  if (intents.length < MIN_MEMBERS) {
    return { viable: false };
  }

  const first = intents[0];
  if (!first) return { viable: false };
  const depositPerRound = first.depositPerRound;
  const duration = first.duration;
  const durationSec = Number(duration);

  for (let n = intents.length; n >= MIN_MEMBERS; n--) {
    const roundLengthSeconds = durationSec / n;
    let beatsSolo = 0;
    for (let k = 1; k <= n; k++) {
      if (positionBeatsSolo(k, n, depositPerRound, roundLengthSeconds, apyBps)) {
        beatsSolo++;
      }
    }
    const shareBps = Math.floor((beatsSolo / n) * 10000);
    if (shareBps >= formationThresholdBps) {
      const memberIds = intents.slice(0, n).map((i) => i.memberId);
      const queueGroupId = `0x${Buffer.from(`${depositPerRound}-${duration}`).toString("hex").padStart(64, "0")}` as `0x${string}`;
      return { viable: true, n, memberIds, queueGroupId, depositPerRound, duration };
    }
  }
  return { viable: false };
}
