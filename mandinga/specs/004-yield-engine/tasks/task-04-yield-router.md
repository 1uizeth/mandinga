# Task 004-04 — Implement YieldRouter

**Spec:** 004 — Yield Engine
**Milestone:** 1
**Status:** Done ✓
**Estimated effort:** 6 hours
**Dependencies:** Task 004-01 (interface), Task 004-03b (SparkUsdcVaultAdapter)
**Parallel-safe:** No

---

## Objective

Implement `YieldRouter.sol` — the central yield orchestration contract. It manages capital allocation across yield source adapters, harvests yield and lets it accrue via share price appreciation (no explicit credit to SavingsAccount), collects the protocol fee, and maintains the circle buffer reserve.

---

## Context

This is the contract that makes the savings account yield-bearing. It receives deposits from `SavingsAccount`, routes 100% to `SparkUsdcVaultAdapter` (sole adapter in v1), harvests yield periodically via share price appreciation (no `creditYield()` call), deducts fee + buffer, and lets net yield raise the share price for all positions automatically.

**v1 simplifications vs original design:**
- Single adapter (SparkUsdcVaultAdapter) — no allocation weights, no `rebalance()`
- No OracleAggregator dependency — circuit breaker reads vault conversion rate directly
- `allocate()` → routes 100% to SparkUsdcVaultAdapter, no weight splitting

See: Spec 004 v0.5.

---

## Acceptance Criteria

### Allocation (simplified — single adapter)
- [x] `_deposit()` override — routes 100% to `sparkAdapter.deposit(assets)`; emits `CapitalAllocated` ✓
- [x] `_withdraw()` override — tries `sparkAdapter.withdraw(assets)`; falls back to `withdrawMax` on `InsufficientLiquidity`; emits `CapitalWithdrawn` ✓
- [x] Constructor: `(address _usdc, address _sparkAdapter, address _savingsAccount, address _circleBuffer, address _treasury)` ✓
- [x] `sparkAdapter` immutable ✓

### Harvesting
- [x] `harvest()` — permissionless; calls `sparkAdapter.harvest()`; deducts fee + buffer; net yield stays in pool; emits `YieldHarvested` ✓
- [x] `harvest()` returns early on zero yield (idempotent) ✓
- [x] 5-minute cooldown — `HARVEST_COOLDOWN = 5 minutes`; reverts `HarvestCooldownActive` ✓

### Circuit Breaker
- [x] APY drop > 50% → sets `circuitBreakerTripped = true`, emits `CircuitBreakerTripped`, returns early ✓
- [x] Subsequent `harvest()` / `allocate()` with flag set → revert `CircuitBreakerActive` ✓
- [x] Withdrawals always available regardless of circuit breaker ✓
- [x] `resetCircuitBreaker()` — onlyOwner ✓

### NatSpec
- [x] All public/external functions have NatSpec ✓

### Security
- [x] Inherits `ReentrancyGuard` ✓
- [x] `nonReentrant` on `deposit()`, `withdraw()`, `mint()`, `redeem()`, `harvest()`, `allocate()` ✓

### Custom Errors
- [x] `CircuitBreakerActive()` (from `IYieldRouter`) ✓
- [x] `HarvestCooldownActive(uint256 nextAllowedAt)` ✓
- [x] `OnlySavingsAccount()` ✓

### Fee Collection
- [x] `feeRateBps` default 1000 (10%), max 2000; `bufferRateBps` default 500 (5%), max 1000 ✓
- [x] `getFeeInfo()` public view ✓

### APY
- [x] `getBlendedAPY()` delegates to `sparkAdapter.getAPY()` ✓

### Tests (22 tests in `test/unit/YieldRouter.t.sol` — all passing)
- [x] Deposit → mock adapter receives full amount ✓
- [x] Harvest → fee (10%) to treasury, buffer (5%) to circleBuffer, share price rises ✓
- [x] Harvest idempotent on zero yield ✓
- [x] Circuit breaker on APY drop — flag set, subsequent harvest/allocate revert ✓
- [x] Withdrawal works when circuit breaker active ✓
- [x] PSM liquidity cap fallback to `withdrawMax` ✓

---

## Output Files

- `contracts/src/yield/YieldRouter.sol`
- `test/unit/YieldRouter.t.sol`

---

## Notes

- Yield distribution is handled via share price appreciation (ERC4626 model) — no per-position distribution, no Merkle-drop. `harvest()` simply lets yield accumulate in the pool, raising `totalAssets()` and thus every share's USDC value automatically.
- `sparkAdapter` is set as an immutable address at construction in v1. v2 will introduce a governance-managed adapter registry.
- The YieldRouter is access-restricted: only `SavingsAccount` can call `deposit()` and `withdraw()`. The `onlySavingsAccount` modifier enforces this.
