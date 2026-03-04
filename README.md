# Mandinga Protocol

A permissionless savings primitive that encodes rotating savings circle (ROSCA) logic into self-custodial, yield-bearing smart contracts.

→ [Read the Lightpaper](./mandinga-lightpaper.md)

---

## What It Is

Mandinga Protocol gives anyone access to lump-sum capital earlier than individual saving allows, the same compounding advantage that historically required wealth to access. Members declare how much they can save and for how long; the protocol matches them into circles, routes yield via the Spark USDC Vault (Sky Savings Rate on Base), and selects payouts via Chainlink VRF.

## Repository Layout

```
mandinga-protocol/
├── contracts/             # Foundry project root (smart contracts)
├── specs/                 # Feature specs (001-006)
│       ├── 001-savings-account/
│       ├── 002-savings-circle/
│       ├── 003-safety-net-pool/
│       ├── 004-yield-engine/
│       ├── 005-privacy-layer/
│       └── 006-automation/
├── front/                 # Next.js 14 frontend (App Router)
├── cre-circle/            # Chainlink CRE automation workflows
├── mandinga-lightpaper.md # Protocol lightpaper v0.2
└── CLAUDE.md              # AI development guidelines
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
cd contracts

# Build
forge build

# Test
forge test

# Invariant tests
forge test --match-path "test/invariant/*" --invariant-runs 10000
```

### Frontend

```bash
cd front

bun install
bun run dev
```

### CRE Workflows

```bash
cd cre-circle

bun install
```

## Feature Specs

| # | Feature | Status |
|---|---------|--------|
| [001](./specs/001-savings-account/) | Savings Account | Implemented |
| [002](./specs/002-savings-circle/) | Savings Circle | In progress |
| [003](./specs/003-safety-net-pool/) | Safety Net Pool | Specified |
| [004](./specs/004-yield-engine/) | Yield Engine (Spark USDC Vault v1) | Specified |
| [005](./specs/005-privacy-layer/) | Privacy Layer | Specified |
| [006](./specs/006-automation/) | CRE Automation | In progress |

## Key Design Decisions

- **Yield source (v1):** Spark USDC Vault (Sky Savings Rate, Base). Real-world yield sources (Ondo, Superstate) deferred to v2
- **Randomness:** Chainlink VRF v2.5. Selection order is verifiably fair, not purchasable
- **Privacy:** `bytes32 shieldedId` throughout state and events. No addresses on-chain
- **Governance:** Equal weight per member regardless of deposit size

## Chainlink Integration

Mandinga Protocol uses three Chainlink products. All files that reference Chainlink are listed below.

### Chainlink CRE (Compute Runtime Environment)

CRE workflows automate protocol-critical operations on a DON (Decentralised Oracle Network). Four workflows are defined; each integrates on-chain state with off-chain computation:

| Workflow | Trigger | Blockchain reads | External data source | Write |
|----------|---------|-----------------|---------------------|-------|
| Circle Formation | Cron 1h | Queue contract (intents), Governance (threshold) | Spark vault APY (kickoff viability) | `formCircle()` |
| Safety Pool Monitor | Cron | SavingsCircle (min-option members), SavingsAccount (balances) | None | None (alert only) |
| Reallocation Trigger | Cron | SavingsCircle (payment status), SavingsAccount (balance) | None | `initiateReallocation()` |
| Yield Harvest | Cron 1x/day | YieldRouter APY | Spark `rateProvider.getConversionRate()` | `harvest()` |

**CRE workflow files:**

| File | Description |
|------|-------------|
| [`cre-circle/workflow/multichain/main.ts`](./cre-circle/workflow/multichain/main.ts) | CRE workflow entry point (`@chainlink/cre-sdk` cron handler) |
| [`cre-circle/workflow/multichain/package.json`](./cre-circle/workflow/multichain/package.json) | `@chainlink/cre-sdk ^1.0.9` dependency |
| [`specs/006-automation/spec.md`](./specs/006-automation/spec.md) | CRE automation layer spec |
| [`specs/006-automation/contracts/workflow-contracts.md`](./specs/006-automation/contracts/workflow-contracts.md) | On-chain interfaces called by workflows |
| [`specs/006-automation/data-model.md`](./specs/006-automation/data-model.md) | Workflow data model (stateless; reads chain each run) |
| [`specs/006-automation/tasks/task-01-cre-setup.md`](./specs/006-automation/tasks/task-01-cre-setup.md) | CRE CLI setup, DON/ACE config |
| [`specs/006-automation/tasks/task-02-foundational.md`](./specs/006-automation/tasks/task-02-foundational.md) | Shared workflow infrastructure |
| [`specs/006-automation/tasks/task-03-circle-formation.md`](./specs/006-automation/tasks/task-03-circle-formation.md) | Circle formation workflow |
| [`specs/006-automation/tasks/task-04-safety-pool-monitor.md`](./specs/006-automation/tasks/task-04-safety-pool-monitor.md) | Safety pool monitor workflow |
| [`specs/006-automation/tasks/task-05-reallocation-trigger.md`](./specs/006-automation/tasks/task-05-reallocation-trigger.md) | Reallocation trigger workflow |
| [`specs/006-automation/tasks/task-06-yield-harvest.md`](./specs/006-automation/tasks/task-06-yield-harvest.md) | Yield harvest workflow |
| [`specs/006-automation/tasks/task-07-don-deployment.md`](./specs/006-automation/tasks/task-07-don-deployment.md) | DON deployment on Base |

**Simulate a workflow (CRE CLI):**

```bash
cd cre-circle/workflow/multichain
bun install
cre workflow simulate
```

### Chainlink VRF v2.5

Used in the Savings Circle to determine payout order. Selection is verifiably random and cannot be purchased (no auction mechanic).

| File | Description |
|------|-------------|
| [`specs/002-savings-circle/spec.md`](./specs/002-savings-circle/spec.md) | VRF v2.5 selection mechanism spec |
| [`specs/002-savings-circle/tasks/task-01-savings-circle-contract.md`](./specs/002-savings-circle/tasks/task-01-savings-circle-contract.md) | `VRFConsumerBaseV2Plus` implementation, `fulfillRandomWords` callback |
| [`contracts/src/interfaces/ISavingsCircle.sol`](./contracts/src/interfaces/ISavingsCircle.sol) | `executeRound()` requests VRF; `fulfillRandomWords()` is VRF-only callback |

### Chainlink Data Feeds *(v2)*

`AggregatorV3Interface` via `OracleAggregator` for multi-source yield rate data. Deferred to v2; Spark `rateProvider.getConversionRate()` is used directly in v1.

| File | Description |
|------|-------------|
| [`specs/004-yield-engine/tasks/task-02-oracle-aggregator.md`](./specs/004-yield-engine/tasks/task-02-oracle-aggregator.md) | `AggregatorV3Interface` integration, multi-feed aggregation |

## License

FLOSS. All contract code is publicly auditable.
