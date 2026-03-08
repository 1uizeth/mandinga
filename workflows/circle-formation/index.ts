import {
  cre,
  Runner,
  type Runtime,
  type CronPayload,
} from "@chainlink/cre-sdk";
import { createCircle, type CreateCircleEvmConfig } from "./tasks/createCircle.js";

type Config = {
  schedule: string;
  evms: CreateCircleEvmConfig[];
  poolSize: string;
  memberCount: number;
  roundDuration: string;
  minDepositPerRound?: string;
};

const onCronTrigger = async (
  runtime: Runtime<Config>,
  _payload: CronPayload
): Promise<string> => {
  const config = runtime.config;
  runtime.log("Circle formation cron trigger fired");

  const evmConfig = config.evms?.[0];
  if (!evmConfig) {
    runtime.log("[createCircle] No evms config — skipping");
    return "createCircle skipped: no evms config";
  }

  const ok = await createCircle(
    runtime,
    evmConfig,
    BigInt(config.poolSize),
    config.memberCount,
    BigInt(config.roundDuration),
    config.minDepositPerRound ? BigInt(config.minDepositPerRound) : 0n
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
