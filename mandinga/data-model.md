# Mandinga Protocol — Data Model

**Version:** 1.0
**Date:** February 2026
**Source specs:** 001 (SavingsAccount), 002 (SavingsCircle), 003 (SolidarityMarket), 004 (YieldEngine)

---

## Entity Map

```
YieldRouter (ERC4626)
    ↑ deposits/redeems shares
SavingsAccount
    ↑ circleObligation set by
SavingsCircle
    ↑ vouch references
SolidarityMarket
```

---

## 1. SavingsAccount

### Position (on-chain struct)

| Field | Type | Description | Invariant |
|---|---|---|---|
| `circleObligationShares` | `uint256` | Minimum shares that cannot be redeemed | `sharesBalance >= circleObligationShares` always |
| `solidarityDebtShares` | `uint256` | Shares owed to Solidarity Pool (entry gap + covered rounds) | Decreases each round; cleared at selection |
| `lastYieldUpdate` | `uint256` | Block timestamp; retained for display/events | — |
| `circleActive` | `bool` | Whether circle participation is active | — |

**Derived (read-only, not stored):**

| Field | Derivation | Description |
|---|---|---|
| `sharesBalance` | `yieldRouter.balanceOf(address(this))` | Total share balance — YieldRouter is source of truth |
| `balance_usdc` | `yieldRouter.convertToAssets(sharesBalance)` | USDC-equivalent of total balance |
| `obligation_usdc` | `yieldRouter.convertToAssets(circleObligationShares)` | USDC-equivalent of locked portion |
| `withdrawable_usdc` | `yieldRouter.convertToAssets(sharesBalance - circleObligationShares)` | Available to withdraw |

**Identity:**
- `shieldedId` = `keccak256(abi.encodePacked(msg.sender, nonce))` — pseudonymous identifier
- `mapping(bytes32 => Position) private positions`
- Never store raw `address` in position state

**State transitions:**

```
[NO POSITION]
    → deposit() → [ACTIVE, circleActive=false]
    → activateCircle() → [ACTIVE, circleActive=true]
    → withdraw() → [ACTIVE] (partial or zero balance)
    → emergencyWithdraw() [emergency state only] → [EXITED]
```

**Key invariant:** `sharesBalance >= circleObligationShares` enforced on every state-modifying function.

---

## 2. YieldRouter (ERC4626 Meta-Vault)

**v1: single adapter (Aave V3 only).** Multi-source routing, allocation weights, and `rebalance()` deferred to v2.

### Core state

| Field | Type | Description |
|---|---|---|
| `asset` | `address` | USDC token address |
| `totalAssets()` | `uint256` (computed) | AaveAdapter balance + idle USDC in contract |
| `aaveAdapter` | `address` (immutable) | Single yield source — AaveAdapter contract address |
| `circuitBreakerActive` | `bool` | Pauses `harvest()` when Aave liquidity critically low |

**Share price model:**
- `sharePrice = totalAssets() / totalSupply()`
- Yield accrues passively — no per-position `creditYield()` needed
- `harvest()` deducts fee (10%) and buffer (5%), net yield stays in pool, share price rises

### CircleBuffer

| Field | Type | Description |
|---|---|---|
| `sharesHeld` | `uint256` | Shares held in YieldRouter for yield smoothing |
| Purpose | — | Absorbs harvest variance; presents stable reported APY |

### Adapters (IYieldSourceAdapter)

Each adapter implements:

| Function | Description |
|---|---|
| `deposit(uint256 assets)` | Route capital to yield source |
| `withdraw(uint256 assets)` | Pull capital from yield source |
| `getBalance() returns (uint256)` | Current balance in 6 decimals (USDC) |
| `getAPY() returns (uint256)` | Current APY in basis points |
| `harvest() returns (uint256)` | Collect and return yield since last harvest |

**Concrete adapters (v1):** `AaveAdapter` only — wraps Aave V3 `IPool`, deposits/withdraws USDC, earns aUSDC, reads APY from `IPoolDataProvider`.

**v2 adapters:** `OndoAdapter` (real-world yield), `CompoundAdapter` — added via governance adapter registry.

---

## 3. SavingsCircle

### Circle (on-chain struct)

| Field | Type | Description |
|---|---|---|
| `poolSize` | `uint256` | Total pool in USDC (= contributionPerMember × memberCount) |
| `contributionPerMember` | `uint256` | Per-member contribution per round in USDC |
| `memberCount` | `uint8` | Fixed circle size (e.g., 10) |
| `roundsCompleted` | `uint8` | Rounds executed so far |
| `totalRounds` | `uint8` | = memberCount (each member gets one payout) |
| `roundDuration` | `uint256` | Seconds between rounds |
| `nextRoundTimestamp` | `uint256` | Timestamp when next round can be executed |
| `status` | `CircleStatus` | FORMING \| ACTIVE \| COMPLETED \| EMERGENCY |
| `members` | `mapping(uint8 => bytes32)` | slot → shieldedId |
| `memberSlots` | `mapping(bytes32 => uint8)` | shieldedId → slot |
| `payoutReceived` | `mapping(uint8 => bool)` | slot → has received payout |
| `positionPaused` | `mapping(uint8 => bool)` | slot → is paused (balance fell below contribution) |

### CircleStatus enum

```
FORMING     → members joining, not yet started
ACTIVE      → rounds executing
COMPLETED   → all members have received payout
EMERGENCY   → emergency state declared
```

**Selection flow:**
1. Anyone calls `executeRound()` after `nextRoundTimestamp`
2. Request Chainlink VRF randomness
3. VRF callback → select eligible (non-paused, not-yet-paid) member from seed
4. `SavingsAccount[selected].circleObligationShares` updated (net payout locked)
5. Emit `MemberSelected(circleId, roundNumber)` — member identity not in event

**Key invariant:** Every member receives full pool payout exactly once per rotation cycle.

---

## 4. SolidarityMarket

### Vouch (on-chain struct)

| Field | Type | Description |
|---|---|---|
| `voucherId` | `bytes32` | shieldedId of voucher |
| `vouchedId` | `bytes32` | shieldedId of vouched member |
| `amount` | `uint256` | Locked vouch amount in USDC |
| `interestRate` | `uint256` | BPS per year earned by voucher |
| `payoutShareBps` | `uint256` | Voucher's share of payout differential at selection |
| `startTimestamp` | `uint256` | Vouch creation timestamp |
| `circleId` | `uint256` | Associated circle |
| `status` | `VouchStatus` | ACTIVE \| PAUSED \| COMPLETED \| EXPIRED |

### VouchStatus enum

```
ACTIVE      → vouch is live; voucher balance portion is locked
PAUSED      → vouched member position paused; vouch obligation paused (not defaulted)
COMPLETED   → vouched member was selected; payout distributed
EXPIRED     → circle completed or vouch duration elapsed
```

**Invariants:**
- Vouched portion of voucher's `SavingsAccount` balance is locked for vouch duration
- No vouch may exceed 80% of voucher's balance (diversification floor)
- Paused member → vouch pauses (not defaults)

---

## 5. Cross-Entity Relationships

```
SavingsAccount
  ← writes circleObligationShares: SavingsCircle (via setCircleObligation)
  ← writes solidarityDebtShares: SolidarityMarket (at vouch creation)
  ← reads sharesBalance: YieldRouter (balanceOf)
  ← deposits/redeems: YieldRouter (deposit/withdraw)

SavingsCircle
  → calls SavingsAccount.setCircleObligation() at round execution
  → calls SavingsAccount.activateCircle() on join
  → requests VRF from Chainlink VRFCoordinator

SolidarityMarket
  → calls SavingsAccount.setSolidarityDebt() at vouch creation
  → receives callback from SavingsCircle at MemberSelected event
  → distributes payout share to voucher's SavingsAccount

YieldRouter
  ← deposits from SavingsAccount only (onlySavingsAccount modifier)
  → routes to AaveAdapter, OndoAdapter
  → pulls yield from adapters on harvest()
  → pushes 5% of yield to CircleBuffer
  → pushes 10% fee to treasury
```

---

## 6. Events (cross-contract)

| Contract | Event | Fields |
|---|---|---|
| SavingsAccount | `Deposited` | `shieldedId`, `amount` |
| SavingsAccount | `Withdrawn` | `shieldedId`, `amount` |
| SavingsAccount | `ObligationSet` | `shieldedId`, `newObligation` |
| SavingsAccount | `EmergencyExitExecuted` | `shieldedId`, `amountReturned` |
| SavingsCircle | `MemberSelected` | `circleId`, `roundNumber` (no member identity) |
| SavingsCircle | `RoundExecuted` | `circleId`, `roundNumber`, `timestamp` |
| SavingsCircle | `CircleCompleted` | `circleId` |
| YieldRouter | `CapitalAllocated` | `amount`, `timestamp` |
| YieldRouter | `YieldHarvested` | `grossYield`, `fee`, `bufferContribution`, `netYield`, `timestamp` |
| YieldRouter | `CircuitBreakerTripped` | `reason`, `timestamp` |
| SolidarityMarket | `VouchCreated` | `vouchId`, `circleId` |
| SolidarityMarket | `PayoutShareDistributed` | `vouchId`, `amount` |

---

## 7. Custom Errors

| Contract | Error | Parameters |
|---|---|---|
| SavingsAccount | `InsufficientWithdrawableBalance` | `requested`, `available` |
| SavingsAccount | `PrincipalLockViolation` | `sharesBalance`, `circleObligationShares` |
| SavingsAccount | `NotAuthorized` | `caller`, `expected` |
| SavingsAccount | `EmergencyNotActive` | — |
| SavingsAccount | `ZeroAmount` | — |
| YieldRouter | `CircuitBreakerActive` | — |
| YieldRouter | `AdapterNotFound` | `adapter` |
| SavingsCircle | `RoundNotReady` | `nextRoundTimestamp`, `current` |
| SavingsCircle | `CircleNotActive` | `status` |
| SolidarityMarket | `VouchExceedsDiversificationFloor` | `amount`, `maxAllowed` |
