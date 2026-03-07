import {
  cre,
  Runner,
  type Runtime,
  type CronPayload,
} from "@chainlink/cre-sdk";
import { createCircle } from "./tasks/createCircle.js";

type Config = {
  schedule: string;
  savingsCircleAddress: string;
  poolSize: string;
  memberCount: number;
  roundDuration: string;
  minDepositPerRound?: string;
  /** Skip waiting for tx receipt (faster simulation) */
  skipReceiptWait?: boolean;
  /** Simulate only, do not broadcast (for cre workflow simulate) */
  dryRun?: boolean;
};

const onCronTrigger = async (
  runtime: Runtime<Config>,
  _payload: CronPayload
): Promise<string> => {
  const config = runtime.config;
  runtime.log("Circle formation cron trigger fired");

  const ok = await createCircle(
    runtime,
    config.savingsCircleAddress as `0x${string}`,
    BigInt(config.poolSize),
    config.memberCount,
    BigInt(config.roundDuration),
    config.minDepositPerRound ? BigInt(config.minDepositPerRound) : 0n,
    config.skipReceiptWait ?? false,
    config.dryRun ?? false
  );

  return ok ? "circle created" : "createCircle failed or skipped";
};

const initWorkflow = (config: Config) => {
  const cronTrigger = new cre.capabilities.CronCapability();
  return [
    cre.handler(cronTrigger.trigger({ schedule: config.schedule }), onCronTrigger),
  ];
};

export async function main() {
  const runner = await Runner.newRunner<Config>();
  await runner.run(initWorkflow);
}

main();
