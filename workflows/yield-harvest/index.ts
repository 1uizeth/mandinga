import {
  cre,
  Runner,
  type Runtime,
  type CronPayload,
} from "@chainlink/cre-sdk";
import { harvest, type HarvestEvmConfig } from "./tasks/harvest.js";

type Config = {
  schedule: string;
  evms: HarvestEvmConfig[];
};

const onCronTrigger = async (
  runtime: Runtime<Config>,
  _payload: CronPayload
): Promise<string> => {
  runtime.log("Yield harvest cron trigger fired");

  const evmConfig = runtime.config.evms?.[0];
  if (!evmConfig) {
    runtime.log("[harvest] No evms config — skipping");
    return "harvest skipped: no evms config";
  }

  const ok = await harvest(runtime, evmConfig);
  return ok ? "harvest executed" : "harvest failed";
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
