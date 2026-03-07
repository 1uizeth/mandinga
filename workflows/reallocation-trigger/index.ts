import { CronCapability, handler, Runner, type Runtime } from "@chainlink/cre-sdk";

type Config = { schedule: string };

const onCronTrigger = (_runtime: Runtime): string => {
  return "reallocation-trigger stub";
};

const initWorkflow = (config: Config) => {
  const cron = new CronCapability();
  return [handler(cron.trigger({ schedule: config.schedule }), onCronTrigger)];
};

export async function main() {
  const runner = await Runner.newRunner<Config>();
  await runner.run(initWorkflow);
}
