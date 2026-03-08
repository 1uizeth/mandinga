# Mandinga Protocol

A permissionless savings primitive that encodes rotating savings circle (ROSCA) logic into self-custodial smart contracts, giving people cooperative access to credit for productive assets without relying on an institution to run the circle.

→ [Read the Lightpaper](./Lightpaper.md)

---

## What It Is

[Savings circles](./Lightpaper.md#12-the-world-invented-the-answer-thousands-of-years-ago) are one of the oldest financial tools in the world. A group of people contribute a fixed amount regularly; the pooled total rotates to one member per round until everyone has received it once. No interest. No credit bureau. No institution in the middle. The mechanic works. Its only structural failure is the [organiser, the person trusted to hold the pot and not disappear](./Lightpaper.md#13-the-structural-failure-mode).

Mandinga Protocol removes the organiser. Members declare how much they can save and for how long; the protocol matches them into circles, enforces contributions through code, selects activation order via Chainlink VRF, and governs itself through the members who participate. When a member is selected, their [position is activated](./Lightpaper.md#32-the-savings-circle-start-with-what-you-can-afford): the full pool is locked in the protocol and attributed to them, continuing to earn yield while remaining obligations settle across the circle. No auctions. No administration fee paid regardless of when you are served.

## How It Works

1. **Deposit** a dollar-stable asset into your self-custodial [savings account](./Lightpaper.md#31-the-savings-account-your-base-layer). It earns yield from the moment it sits.
2. **Declare** your installment (how much you can contribute per period) and duration (for how long). That is the entire input.
3. **Match**: the protocol finds other members with the same parameters and forms a circle. The pool size emerges from the match; you never had to name it.
4. **Round by round**, each member pays their installment. [Chainlink VRF](./Lightpaper.md#32-the-savings-circle-start-with-what-you-can-afford) selects one member per round in a verifiably random order that cannot be purchased or influenced.
5. **Activation**: when selected, your position is marked active. The full pool is locked to you in the protocol and earns yield while your remaining installments settle automatically.
6. **Completion**: when the circle closes, all positions settle. The direction for v2: [active positions become claims on real assets](./Lightpaper.md#from-activation-to-ownership), with the protocol as silent lienholder until obligations are met.

## Chainlink Integration

Mandinga Protocol uses three Chainlink products. All relevant files are listed below.

### Chainlink VRF v2.5

The core fairness guarantee of the savings circle. Selection order is determined by verifiable on-chain randomness. It cannot be purchased, predicted, or influenced. This directly replaces the auction mechanic (the lance) that [broke the cooperative logic of traditional consórcios](./Lightpaper.md#14-case-study-what-happened-to-the-consórcio-in-brazil).

| File | Description |
|------|-------------|
| [`mandinga/specs/002-savings-circle/spec.md`](./mandinga/specs/002-savings-circle/spec.md) | VRF v2.5 selection mechanism spec |
| [`mandinga/specs/002-savings-circle/tasks/task-01-savings-circle-contract.md`](./mandinga/specs/002-savings-circle/tasks/task-01-savings-circle-contract.md) | `VRFConsumerBaseV2Plus` implementation, `fulfillRandomWords` callback |
| [`contracts/src/interfaces/ISavingsCircle.sol`](./contracts/src/interfaces/ISavingsCircle.sol) | `executeRound()` requests VRF; `fulfillRandomWords()` is VRF-only callback |

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
| [`workflows/circle-formation/index.ts`](./workflows/circle-formation/index.ts) | Circle formation workflow entry point |
| [`workflows/yield-harvest/index.ts`](./workflows/yield-harvest/index.ts) | Yield harvest workflow entry point |
| [`mandinga/specs/006-automation/spec.md`](./mandinga/specs/006-automation/spec.md) | CRE automation layer spec |
| [`mandinga/specs/006-automation/contracts/workflow-contracts.md`](./mandinga/specs/006-automation/contracts/workflow-contracts.md) | On-chain interfaces called by workflows |
| [`mandinga/specs/006-automation/data-model.md`](./mandinga/specs/006-automation/data-model.md) | Workflow data model (stateless; reads chain each run) |

**Simulate a workflow (CRE CLI):**

```bash
cd workflows/circle-formation
bun install
cre workflow simulate
```

### Chainlink Data Feeds *(v2)*

`AggregatorV3Interface` via `OracleAggregator` for multi-source yield rate data. Deferred to v2; Spark `rateProvider.getConversionRate()` is used directly in v1.

| File | Description |
|------|-------------|
| [`mandinga/specs/004-yield-engine/tasks/task-02-oracle-aggregator.md`](./mandinga/specs/004-yield-engine/tasks/task-02-oracle-aggregator.md) | `AggregatorV3Interface` integration, multi-feed aggregation |

## Feature Specs

| # | Feature | Status |
|---|---------|--------|
| [001](./mandinga/specs/001-savings-account/) | Savings Account | Implemented |
| [002](./mandinga/specs/002-savings-circle/) | Savings Circle | In progress |
| [003](./mandinga/specs/003-safety-net-pool/) | Safety Net Pool | Specified |
| [004](./mandinga/specs/004-yield-engine/) | Yield Engine (Spark USDC Vault v1) | Specified |
| [005](./mandinga/specs/005-privacy-layer/) | Privacy Layer | Specified |
| [006](./mandinga/specs/006-automation/) | CRE Automation | In progress |
| [007](./mandinga/specs/007-defi-dashboard/) | DeFi Dashboard | In progress |

### [Savings Account](./Lightpaper.md#31-the-savings-account-your-base-layer)
Every member starts here. Deposit a dollar-stable asset and it earns yield automatically, routed to the Spark USDC Vault (Sky Savings Rate on Base). No management required.

### [Savings Circle](./Lightpaper.md#32-the-savings-circle-start-with-what-you-can-afford)
Declare an installment and duration. The protocol matches you into a circle and handles everything: round scheduling, contribution tracking, and selection via Chainlink VRF. No organiser. No auction. Your turn is guaranteed.

**Example:** Ten members each contributing $100/month form a $1,000 pool. The member activated in round one has access to that credit nine months before the member activated in round ten. The rotation distributes the timing advantage equally. No capital required to go first.

### [Minimum Installment Option](./Lightpaper.md#the-minimum-installment-a-built-in-safety-net)
Declare a minimum installment (default: half your full installment) when joining. On difficult months, pay the minimum; the Safety Net Pool covers the difference. A small interest charge accrues and settles automatically when your position is activated. No credit check. No application.

**Example:** A member contributing $50/month can guarantee $25 in any given round. The Safety Net Pool covers the remaining $25, keeping the circle running without interruption.

### [Safety Net Pool](./Lightpaper.md#33-the-safety-net-pool-making-the-safety-net-possible)
Members with idle savings capacity deposit into the pool and earn yield on locked capital plus interest from covered members. Their capital backs minimum installment coverage across multiple circles, generating a passive return while amplifying access for others.

**Example:** A member deposits $500 into the Safety Net Pool for 12 months. They earn the same base yield as a savings account, plus interest from every member whose shortfall their capital covered that year.

### [Cooperative Governance](./Lightpaper.md#2-the-principles)
Governance weight is equal per member regardless of deposit size. Protocol-level decisions are made by participants, not token holders or administrators.

## Repository Layout

```
mandinga/
├── contracts/             # Foundry project root (smart contracts)
├── workflows/             # Chainlink CRE automation workflows
├── webapp/                # Next.js 14 frontend (App Router)
├── mandinga/
│   └── specs/             # Feature specs
│       ├── 001-savings-account/
│       ├── 002-savings-circle/
│       ├── 003-safety-net-pool/
│       ├── 004-yield-engine/
│       ├── 005-privacy-layer/
│       ├── 006-automation/
│       └── 007-defi-dashboard/
├── Lightpaper.md          # Protocol lightpaper v0.3
└── CLAUDE.md              # Development guidelines
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

forge build
forge test
forge test --match-path "test/invariant/*" --invariant-runs 10000
```

### Frontend

```bash
cd webapp

pnpm install
pnpm dev
```

### CRE Workflows

```bash
cd workflows

bun install
```

## Key Design Decisions

- **Yield source (v1):** Spark USDC Vault (Sky Savings Rate, Base). Real-world yield sources deferred to v2
- **Randomness:** Chainlink VRF v2.5. Selection order is verifiably fair, not purchasable
- **Credit activation:** selected member's position is locked in the protocol, not withdrawn as liquid funds. [Asset integration is v2](./Lightpaper.md#from-activation-to-ownership)
- **Privacy:** `bytes32 shieldedId` throughout state and events. No addresses on-chain (v2)
- **Governance:** Equal weight per member regardless of deposit size

## Roadmap

### v1 — Current
- Self-custodial savings account with on-chain yield (Spark USDC Vault)
- Circle matching by installment and duration
- Chainlink VRF v2.5 for verifiably fair, non-purchasable selection order
- Safety Net Pool with minimum installment coverage
- Chainlink CRE automation: circle formation, yield harvest, safety pool monitoring, reallocation triggers
- Equal-weight cooperative governance

### v2 — Planned
- [Proof of selection and real-world asset integration](./Lightpaper.md#from-activation-to-ownership): active positions become claims on productive assets, with the protocol as lienholder until obligations are met
- Privacy layer: shielded balances, contribution history, and circle membership
- Chainlink Data Feeds via `OracleAggregator` for multi-source yield rate data
- Real-world yield sources (Ondo, Superstate) alongside Spark

## License

FLOSS. All contract code is publicly auditable.
