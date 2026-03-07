#!/usr/bin/env bun
/**
 * Sync ABIs from contracts/out/ (Foundry) to workflows/contracts/abi/
 * Run from repo root: bun run workflows/scripts/sync-abi.ts
 * Or from workflows/: bun run sync-abi
 */
import { cp, mkdir, readFile, writeFile } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const CONTRACTS_OUT = join(REPO_ROOT, "contracts", "out");
const ABIS_DEST = join(REPO_ROOT, "workflows", "contracts", "abi");

const ABIS: { src: string; dest: string }[] = [
  { src: "YieldRouter.sol/YieldRouter.json", dest: "YieldRouter.json" },
  { src: "SavingsCircle.sol/SavingsCircle.json", dest: "SavingsCircle.json" },
  { src: "SavingsAccount.sol/SavingsAccount.json", dest: "SavingsAccount.json" },
  { src: "SafetyNetPool.sol/SafetyNetPool.json", dest: "SafetyNetPool.json" },
];

async function sync() {
  await mkdir(ABIS_DEST, { recursive: true });
  let synced = 0;
  for (const { src, dest } of ABIS) {
    const srcPath = join(CONTRACTS_OUT, src);
    const destPath = join(ABIS_DEST, dest);
    try {
      const content = await readFile(srcPath, "utf-8");
      const artifact = JSON.parse(content);
      const abiOnly = { abi: artifact.abi };
      await writeFile(destPath, JSON.stringify(abiOnly, null, 2));
      console.log(`Synced ${dest}`);
      synced++;
    } catch (err) {
      console.warn(`Skip ${dest}: ${err instanceof Error ? err.message : err}`);
    }
  }
  console.log(`Synced ${synced}/${ABIS.length} ABIs`);
}

sync().catch(console.error);
