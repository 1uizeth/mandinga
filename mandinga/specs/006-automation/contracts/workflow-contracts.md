# Spec 006 — Workflow Contract Interfaces

**Purpose**: Document the on-chain contracts and methods that CRE workflows call or read. Backend must implement these interfaces for CRE integration.

---

## Circle Formation Workflow

**Source**: Spec 002 US-006 (AC-006-1 to AC-006-4). Kickoff algorithm runs off-chain in CRE; workflow submits result.

### Read (view/pure)

| Contract | Method | Purpose |
|----------|--------|---------|
| Queue | `getQueuedIntents(uint256 depositPerRound, uint256 duration)` | Group queue by params; returns intents for kickoff |
| YieldRouter | `getBlendedAPY()` or equivalent | Kickoff viability (AC-006-2) |
| Governance | `formationThreshold()` | Default 70% (AC-006-3) |

### Write

| Contract | Method | Purpose |
|----------|--------|---------|
| Formation / CircleFactory | `formCircle(bytes32 queueGroupId, uint8 selectedN, bytes32[] memberIds)` | Create circle; backend implements per Spec 002 US-006 |

---

## Safety Pool Monitor Workflow

### Read only — no writes

| Contract | Method | Purpose |
|----------|--------|---------|
| SavingsCircle | `getActiveCircles()`, `getMembersWithMinOption(circleId)` | Find members needing coverage |
| SavingsAccount | `getBalance(shieldedId)` | Compare to depositPerRound |

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

ABIs are synced from `backend/out/` to `workflows/contracts/abi/`:

- `YieldRouter.json`
- `SavingsCircle.json` (or equivalent)
- `SavingsAccount.json`
- `SafetyNetPool.json`
- Formation/Queue contract (TBD)
