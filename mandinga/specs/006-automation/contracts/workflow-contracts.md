# Spec 006 — Workflow Contract Interfaces

**Purpose**: Document the on-chain contracts and methods that CRE workflows call or read. Backend must implement these interfaces for CRE integration.

---

## Circle Formation Workflow

**Source**: Spec 002 US-006 (AC-006-1 to AC-006-4). Kickoff algorithm runs off-chain in CRE; workflow submits result.

**Gap:** Queue contract (`getQueuedIntents`) not deployed. Until it exists, use one of:
- **intentsUrl** — HTTP GET to backend API returning `{ intents: { memberId, depositPerRound, duration }[] }`
- **intents** — Config array for testing (same shape)
- **Queue contract** — When deployed, call `getQueuedIntents(depositPerRound, duration)` on Queue address

### Read (view/pure) — target interface when Queue/Formation exist

| Contract | Method | Purpose |
|----------|--------|---------|
| Queue | `getQueuedIntents(uint256 depositPerRound, uint256 duration)` | Group queue by params; returns intents for kickoff |
| YieldRouter | `getBlendedAPY()` or equivalent | Kickoff viability (AC-006-2) |
| Governance | `formationThreshold()` | Default 70% (AC-006-3) |

### Write — circle formation (SavingsCircle)

| Contract | Method | Purpose |
|----------|--------|---------|
| SavingsCircle | `createCircle(poolSize, memberCount, roundDuration, minDepositPerRound)` | Create circle in FORMING state; workflow derives params from kickoff |
| SavingsCircle | `joinCircle(circleId)` | Per-member; called by each member (msg.sender), not by workflow |

**ABI:** `workflows/contracts/abi/SavingsCircle.json` (synced from `contracts/out/`).

---

## Safety Pool Monitor Workflow

### Read only — no writes

| Contract | Method | Purpose |
|----------|--------|---------|
| SavingsCircle | `getActiveCircles()`, `getMembersWithMinOption(circleId)` | Find members needing coverage |
| SavingsAccount | `getWithdrawableBalance(shieldedId)` | Compare to depositPerRound (or minDepositPerRound for min-installment members) |

---

## Reallocation Trigger Workflow

### Read

| Contract | Method | Purpose |
|----------|--------|---------|
| SavingsCircle | `getCircles()`, `getMemberPaymentStatus(circleId, memberId, round)` | Detect 1-round non-payment |
| SavingsAccount | `getBalance(shieldedId)` | vs minDepositPerRound |

### Write

| Contract | Method | Purpose |
|----------|--------|---------|
| SavingsCircle | `initiateReallocation(circleId, memberId)` | Start reallocation (R-003) |

---

## Yield Harvest Workflow

### Write

| Contract | Method | Purpose |
|----------|--------|---------|
| YieldRouter | `harvest()` | Collect yield; raise share price |

### Read (optional monitoring)

| Contract | Method | Purpose |
|----------|--------|---------|
| YieldRouter | `getBlendedAPY()` | Alerting |
| AaveAdapter | Supply rate | Circuit breaker input |

---

## ABI Sync

ABIs are synced from `contracts/out/` (Foundry) to `workflows/contracts/abi/`:

- `YieldRouter.json`
- `SavingsCircle.json` (or equivalent)
- `SavingsAccount.json`
- `SafetyNetPool.json`
- Formation/Queue contract (TBD)
