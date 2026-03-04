# Mandinga Protocol

A permissionless savings primitive that encodes rotating savings circle (ROSCA) logic into self-custodial, yield-bearing smart contracts.

→ [Read the Lightpaper](./mandinga-lightpaper.md)

---

## What It Is

Mandinga Protocol gives anyone access to lump-sum capital earlier than individual saving allows — the same compounding advantage that historically required wealth to access. Members declare how much they can save and for how long; the protocol matches them into circles, routes yield via Aave V3, and selects payouts via Chainlink VRF. No auctions. No organiser. No KYC.

## Repository Layout

```
mandinga-protocol/
├── mandinga/                  # Smart contracts + feature specs
│   ├── contracts/             # Interface documentation
│   └── specs/                 # Feature specs (001–006)
│       ├── 001-savings-account/
│       ├── 002-savings-circle/
│       ├── 003-solidarity-market/
│       ├── 004-yield-engine/
│       ├── 005-privacy-layer/
│       └── 006-automation/
├── mandinga_front/            # Next.js 14 frontend (App Router)
├── cre-manding-circle/        # Chainlink CRE automation workflows
├── mandinga-lightpaper.md     # Protocol lightpaper v0.2
└── CLAUDE.md                  # AI development guidelines
```

## Prerequisites

| Tool | Version |
|------|---------|
| [Foundry](https://getfoundry.sh) | latest |
| [Bun](https://bun.sh) | 1.x |
| Node.js | 20+ |

## Quick Start

### Contracts

```bash
cd mandinga

# Build
forge build

# Test
forge test

# Invariant tests
forge test --match-path "test/invariant/*" --invariant-runs 10000
```

### Frontend

```bash
cd mandinga_front

bun install
bun run dev
```

### CRE Workflows

```bash
cd cre-manding-circle

bun install
```

## Feature Specs

| # | Feature | Status |
|---|---------|--------|
| [001](./mandinga/specs/001-savings-account/) | Savings Account | Implemented |
| [002](./mandinga/specs/002-savings-circle/) | Savings Circle | In progress |
| [003](./mandinga/specs/003-solidarity-market/) | Solidarity Market | Specified |
| [004](./mandinga/specs/004-yield-engine/) | Yield Engine (Aave v1) | Specified |
| [005](./mandinga/specs/005-privacy-layer/) | Privacy Layer | Specified |
| [006](./mandinga/specs/006-automation/) | CRE Automation | In progress |

## Key Design Decisions

- **Yield source (v1):** Aave V3 only — real-world yield sources (Ondo, Superstate) deferred to v2
- **Randomness:** Chainlink VRF v2.5 — selection order is verifiably fair, not purchasable
- **Privacy:** `bytes32 shieldedId` throughout state and events — no addresses on-chain
- **Governance:** Equal weight per member regardless of deposit size

---

## Chainlink Integration

Mandinga Protocol uses three Chainlink products. All files that reference Chainlink are listed below.

### Chainlink CRE (Compute Runtime Environment)

CRE workflows automate protocol-critical operations on a DON (Decentralised Oracle Network). Four workflows are defined; each integrates on-chain state with off-chain computation:

| Workflow | Trigger | Blockchain reads | External data source | Write |
|----------|---------|-----------------|---------------------|-------|
| Circle Formation | Cron 1h | Queue contract (intents), Governance (threshold) | Aave V3 pool APY (kickoff viability) | `formCircle()` |
| Safety Pool Monitor | Cron | SavingsCircle (min-option members), SavingsAccount (balances) | — | None (alert only) |
| Reallocation Trigger | Cron | SavingsCircle (payment status), SavingsAccount (balance) | — | `initiateReallocation()` |
| Yield Harvest | Cron 1x/day | YieldRouter APY | Aave V3 supply rate | `harvest()` |

**CRE workflow files:**

| File | Description |
|------|-------------|
| [`cre-manding-circle/workflow/multichain/main.ts`](./cre-manding-circle/workflow/multichain/main.ts) | CRE workflow entry point — `@chainlink/cre-sdk` cron handler |
| [`cre-manding-circle/workflow/multichain/package.json`](./cre-manding-circle/workflow/multichain/package.json) | `@chainlink/cre-sdk ^1.0.9` dependency |
| [`mandinga/specs/006-automation/spec.md`](./mandinga/specs/006-automation/spec.md) | CRE automation layer spec |
| [`mandinga/specs/006-automation/contracts/workflow-contracts.md`](./mandinga/specs/006-automation/contracts/workflow-contracts.md) | On-chain interfaces called by workflows |
| [`mandinga/specs/006-automation/data-model.md`](./mandinga/specs/006-automation/data-model.md) | Workflow data model (stateless; reads chain each run) |
| [`mandinga/specs/006-automation/tasks/task-01-cre-setup.md`](./mandinga/specs/006-automation/tasks/task-01-cre-setup.md) | CRE CLI setup, DON/ACE config |
| [`mandinga/specs/006-automation/tasks/task-02-foundational.md`](./mandinga/specs/006-automation/tasks/task-02-foundational.md) | Shared workflow infrastructure |
| [`mandinga/specs/006-automation/tasks/task-03-circle-formation.md`](./mandinga/specs/006-automation/tasks/task-03-circle-formation.md) | Circle formation workflow |
| [`mandinga/specs/006-automation/tasks/task-04-safety-pool-monitor.md`](./mandinga/specs/006-automation/tasks/task-04-safety-pool-monitor.md) | Safety pool monitor workflow |
| [`mandinga/specs/006-automation/tasks/task-05-reallocation-trigger.md`](./mandinga/specs/006-automation/tasks/task-05-reallocation-trigger.md) | Reallocation trigger workflow |
| [`mandinga/specs/006-automation/tasks/task-06-yield-harvest.md`](./mandinga/specs/006-automation/tasks/task-06-yield-harvest.md) | Yield harvest workflow |
| [`mandinga/specs/006-automation/tasks/task-07-don-deployment.md`](./mandinga/specs/006-automation/tasks/task-07-don-deployment.md) | DON deployment on Base |

**Simulate a workflow (CRE CLI):**

```bash
cd cre-manding-circle/workflow/multichain
bun install
cre workflow simulate
```

### Chainlink VRF v2.5

Used in the Savings Circle to determine payout order. Selection is verifiably random and cannot be purchased (no auction mechanic).

| File | Description |
|------|-------------|
| [`mandinga/specs/002-savings-circle/spec.md`](./mandinga/specs/002-savings-circle/spec.md) | VRF v2.5 selection mechanism spec |
| [`mandinga/specs/002-savings-circle/tasks/task-01-savings-circle-contract.md`](./mandinga/specs/002-savings-circle/tasks/task-01-savings-circle-contract.md) | `VRFConsumerBaseV2Plus` implementation, `fulfillRandomWords` callback |
| [`mandinga/contracts/ISavingsCircle.md`](./mandinga/contracts/ISavingsCircle.md) | `executeRound()` — requests VRF; `fulfillRandomWords()` — VRF-only callback |

### Chainlink Data Feeds *(v2)*

`AggregatorV3Interface` via `OracleAggregator` for multi-source yield rate data. Deferred to v2 — Aave V3 on-chain rate is used directly in v1.

| File | Description |
|------|-------------|
| [`mandinga/specs/004-yield-engine/tasks/task-02-oracle-aggregator.md`](./mandinga/specs/004-yield-engine/tasks/task-02-oracle-aggregator.md) | `AggregatorV3Interface` integration, multi-feed aggregation |

---

## License

FLOSS — all contract code is publicly auditable.
