import {
  cre,
  Runner,
  type Runtime,
  type CronPayload,
} from "@chainlink/cre-sdk";
import { executeRound, type ExecuteRoundEvmConfig } from "./tasks/executeRound.js";

type Config = {
  schedule: string;
  evms: ExecuteRoundEvmConfig[];
  circleId: string;
};

const onCronTrigger = async (
  runtime: Runtime<Config>,
  _payload: CronPayload
): Promise<string> => {
  const config = runtime.config;
  runtime.log("Execute round cron trigger fired");

  const evmConfig = config.evms?.[0];
  if (!evmConfig) {
    runtime.log("[executeRound] No evms config — skipping");
    return "executeRound skipped: no evms config";
  }

  const ok = await executeRound(
    runtime,
    evmConfig,
    BigInt(config.circleId)
  );

  return ok ? "round executed" : "executeRound failed or skipped";
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
