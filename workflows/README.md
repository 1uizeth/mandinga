# Mandinga CRE Workflows

Spec 006 — Automation Layer (Chainlink CRE). Four workflows for protocol automation on Base.

## Prerequisites

1. **CRE CLI** — [Install](https://docs.chain.link/cre); `cre --version` succeeds
2. **Bun** — [Install](https://bun.sh)
3. **Contracts** deployed on Base Sepolia (for integration tests)

## Setup

```bash
# From repo root
cd workflows
bun install

# Add private key to .env (for chain writes)
cp .env.example .env
# Edit .env and set CRE_ETH_PRIVATE_KEY

# Secrets: circle-formation uses secrets.yaml (secrets-path: "../secrets.yaml").
# For simulation, CRE loads CRE_ETH_PRIVATE_KEY from .env. Ensure workflows/.env exists.
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
