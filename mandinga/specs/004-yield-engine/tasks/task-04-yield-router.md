# Task 004-04 — Implement YieldRouter

**Spec:** 004 — Yield Engine
**Milestone:** 1
**Status:** Blocked on Task 004-03 only (OracleAggregator deferred to v2)
**Estimated effort:** 6 hours
**Dependencies:** Task 004-01 (interface), Task 004-03 (AaveAdapter)
**Parallel-safe:** No

---

## Objective

Implement `YieldRouter.sol` — the central yield orchestration contract. It manages capital allocation across multiple yield source adapters, harvests yield, credits it to the SavingsAccount, collects the protocol fee, and maintains the circle buffer reserve.

---

## Context

This is the contract that makes the savings account yield-bearing. It receives deposits from `SavingsAccount`, routes 100% to `AaveAdapter` (sole adapter in v1), harvests yield periodically via share price appreciation (no `creditYield()` call), deducts fee + buffer, and lets net yield raise the share price for all positions automatically.

**v1 simplifications vs original design:**
- Single adapter (AaveAdapter) — no allocation weights, no `rebalance()`
- No OracleAggregator dependency — circuit breaker reads Aave liquidity directly
- `allocate()` → routes 100% to AaveAdapter, no weight splitting

See: Spec 004 v0.4, plan.md §3.4.

---

## Acceptance Criteria

### Allocation (simplified — single adapter)
- [ ] `_deposit()` override — called by ERC4626 on deposit:
  - Receives USDC (pulled by ERC4626 `deposit()`)
  - Routes 100% to `aaveAdapter.deposit(assets)`
  - Emits `CapitalAllocated(amount, timestamp)`
- [ ] `_withdraw()` override — called by ERC4626 on withdrawal:
  - Pulls USDC from `aaveAdapter.withdraw(assets)` before transferring to receiver
  - Emits `CapitalWithdrawn(amount, timestamp)`
- [ ] `aaveAdapter` address is immutable — set at construction, not changeable in v1 (v2 will add governance-managed adapter registry)

### Harvesting
- [ ] `harvest()` — callable by anyone, executes the yield distribution cycle:
  - Calls `adapter.harvest()` on all active adapters
  - Sums total yield collected
  - Deducts protocol fee (`totalYield * feeRateBps / 10000`) → transfers to treasury
  - Deducts buffer contribution (`totalYield * bufferRateBps / 10000`) → credits to `CircleBuffer`
  - Distributes remaining yield proportionally across all savings positions
  - Emits `YieldHarvested(grossYield, protocolFee, bufferContribution, netYield)`
- [ ] `harvest()` is idempotent within a single block — calling twice returns 0 on second call
- [ ] `harvest()` is callable no more than once per hour (prevents MEV griefing)

### Circuit Breaker (simplified for single adapter)
- [ ] Before every `harvest()`, check Aave's available USDC liquidity via `aaveAdapter.getBalance()`:
  - If liquidity is critically low (below governance-set threshold), pause `harvest()` only
  - Log circuit breaker state in emitted event
  - Withdrawals always available regardless of circuit breaker state
- [ ] No `rebalance()` function in v1 — single adapter means nothing to rebalance

### Fee Collection
- [ ] `feeRateBps` — configurable by governance, default 1000 (10%), hard ceiling 2000 (20%), hard floor 0
- [ ] `bufferRateBps` — configurable by governance, default 500 (5%), hard ceiling 1000 (10%)
- [ ] Treasury address configurable by governance with 7-day timelock
- [ ] `getFeeInfo() returns (uint256 feeRate, uint256 bufferRate, address treasury)` — public view

### APY
- [ ] `getBlendedAPY() returns (uint256 apyBps)`:
  - Returns `aaveAdapter.getAPY()` directly (single source, no weighting needed)
  - `getAPY()` on AaveAdapter reads from `IPoolDataProvider.getReserveData(USDC).currentLiquidityRate`

### Tests
- [ ] Unit tests at `backend/test/unit/YieldRouter.t.sol` using a mock AaveAdapter:
  - Deposit 1000 USDC → mock adapter receives full amount
  - Harvest → gross yield collected, fee (10%) deducted, buffer (5%) deducted, share price rises
  - `harvest()` twice in one block → second call harvests 0 (idempotent)
  - Circuit breaker: mock adapter returns critically low balance → `harvest()` paused, `withdraw()` still works
  - Withdrawal: correct USDC amount returned from adapter

---

## Output Files

- `backend/contracts/yield/YieldRouter.sol`
- `backend/test/unit/YieldRouter.t.sol`

---

## Notes

- Yield distribution is handled via share price appreciation (ERC4626 model) — no per-position distribution, no Merkle-drop. `harvest()` simply lets yield accumulate in the pool, raising `totalAssets()` and thus every share's USDC value automatically.
- `aaveAdapter` is set as an immutable address at construction in v1. v2 will introduce a governance-managed adapter registry.
- The YieldRouter is access-restricted: only `SavingsAccount` can call `deposit()` and `withdraw()`. The `onlySavingsAccount` modifier enforces this.
