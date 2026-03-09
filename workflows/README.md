# Mandinga CRE Workflows

Spec 006 — Automation Layer (Chainlink CRE). Four workflows for protocol automation on Base.

> **Documentation:** See [CRE-WORKFLOWS.md](./CRE-WORKFLOWS.md) for a detailed guide on how each workflow works, why it exists, and flow diagrams.

## Prerequisites

1. **CRE CLI** — [Install](https://docs.chain.link/cre); `cre --version` succeeds
2. **Bun** — [Install](https://bun.sh)
3. **Contracts** deployed on Base Sepolia (for integration tests)

## Setup

```bash
# From repo root
cd workflows
bun install

# Add private key to .env (for other workflows that need it)
cp .env.example .env

# Circle formation uses CRE report + writeReport (no private key needed).
# Deploy CircleFormationConsumer first (see Circle Formation below).
```

## Sync ABIs

ABIs are synced from `contracts/out/` (Foundry) to `workflows/contracts/abi/`:

```bash
# From repo root
cd contracts && forge build && cd ..
bun run workflows/scripts/sync-abi.ts

# Or from workflows/
bun run sync-abi
```

## Required ABIs

| Source (contracts/out/) | Dest (workflows/contracts/abi/) |
|------------------------|---------------------------------|
| YieldRouter.sol/YieldRouter.json | YieldRouter.json |
| SavingsCircle.sol/SavingsCircle.json | SavingsCircle.json |
| SavingsAccount.sol/SavingsAccount.json | SavingsAccount.json |
| SafetyNetPool.sol/SafetyNetPool.json | SafetyNetPool.json |

## Simulate Workflows

`project.yaml` is in `workflows/`. **Run from `workflows/`** so CRE finds it:

```bash
cd workflows
cre workflow simulate circle-formation --target base-sepolia
cre workflow simulate safety-pool-monitor --target base-sepolia
cre workflow simulate reallocation-trigger --target base-sepolia
cre workflow simulate yield-harvest --target base-sepolia
```

From repo root, use `-R workflows` to set project root:
```bash
cre workflow simulate workflows/circle-formation -R workflows --target base-sepolia
```

## Workflow Schedules

| Workflow | Cron | Chain |
|----------|------|-------|
| circle-formation | `0 * * * *` (every 1h) | Base |
| safety-pool-monitor | Round-aligned or every N min | Base |
| reallocation-trigger | Round-aligned | Base |
| yield-harvest | `*/5 * * * *` (every 5 min) | Base |

## Circle Formation — CRE Onchain Write

Circle formation uses the CRE report + writeReport pattern ([Part 4: Writing Onchain](https://docs.chain.link/cre/getting-started/part-4-writing-onchain-ts)).

### 1. Deploy CircleFormationConsumer

Get the Forwarder address for Base Sepolia from the [Forwarder Directory](https://docs.chain.link/cre/guides/workflow/using-evm-client/forwarder-directory):
- **Simulation**: use MockForwarder address
- **Production**: use KeystoneForwarder address

```bash
# From contracts/
export FORWARDER_ADDRESS=0x...  # From Forwarder Directory
forge script script/DeployCircleFormationConsumer.s.sol --broadcast --rpc-url https://base-sepolia-rpc.publicnode.com
```

### 2. Update config

Edit `circle-formation/config.base-sepolia.json` and set `consumerAddress` to the deployed consumer:

```json
"consumerAddress": "0x<deployed CircleFormationConsumer address>"
```

### 3. Simulate (with --broadcast for real tx)

```bash
cre workflow simulate circle-formation --target base-sepolia --broadcast
```

By default, `cre workflow simulate` performs a dry run for writes (no broadcast). Add `--broadcast` to execute a real transaction.

---

## Yield Harvest — CRE Onchain Write

Yield harvest runs every 5 minutes and calls `YieldRouter.harvest()` via the same report + writeReport pattern.

### 1. Deploy YieldHarvestConsumer

```bash
cd contracts
export FORWARDER_ADDRESS=0x...   # From Forwarder Directory
forge script script/DeployYieldHarvestConsumer.s.sol --broadcast --rpc-url https://base-sepolia-rpc.publicnode.com
```

### 2. Update config

Edit `yield-harvest/config.base-sepolia.json` and set `consumerAddress` to the deployed consumer. The `yieldRouterAddress` is pre-configured for Base Sepolia (`0xC2991B227fDEb92d9DAC68E3e7fc8DD5E30a0E64`).

### 3. Simulate

```bash
cre workflow simulate yield-harvest --target base-sepolia --broadcast
```

---

## Circle Formation — Intent Sources (Queue not deployed)

Until the Queue contract exists, use one of:

1. **config.intents** — Add to `config.base-sepolia.json` for testing:
   ```json
   "intents": [
     { "memberId": "0x...", "depositPerRound": 100, "duration": 365 }
   ]
   ```
   `depositPerRound` in USDC, `duration` in days.

2. **config.intentsUrl** — HTTP URL returning `{ intents: [...] }`. Backend stores intents from webapp.

3. **Queue contract** — When deployed, set `queueAddress` in config.

## Structure

- `lib/` — Shared: getBaseRpcUrl, errorHandler
- `circle-formation/` — US1: auto circle formation
- `safety-pool-monitor/` — US2: monitor & alert (read-only)
- `reallocation-trigger/` — US3: initiate reallocation (1 round grace)
- `yield-harvest/` — US4: YieldRouter.harvest()

See [mandinga/specs/006-automation/quickstart.md](../mandinga/specs/006-automation/quickstart.md).
