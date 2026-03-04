# Task 004-04 — Implement YieldRouter

**Spec:** 004 — Yield Engine
**Milestone:** 1
**Status:** Blocked on Task 004-03b only (OracleAggregator deferred to v2)
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
- [ ] `_deposit()` override — called by ERC4626 on deposit:
  - Receives USDC (pulled by ERC4626 `deposit()`)
  - Routes 100% to `sparkAdapter.deposit(assets)`
  - Emits `CapitalAllocated(amount, timestamp)`
- [ ] `_withdraw()` override — called by ERC4626 on withdrawal:
  - Calls `sparkAdapter.withdraw(assets)`; if it reverts with `InsufficientLiquidity`, falls back to `sparkAdapter.withdrawMax(assets)` to retrieve the maximum available amount
  - Emits `CapitalWithdrawn(amount, timestamp)`
- [ ] Constructor immutables: `(address _sparkAdapter, address _savingsAccount, address _circleBuffer, address _treasury)`
  - `sparkAdapter` — sole yield adapter in v1
  - `savingsAccount` — only caller allowed for `deposit()`/`withdraw()`
  - `circleBuffer` — receives buffer share of yield; contract defined in Spec 003
  - `treasury` — receives protocol fee; governed by multisig
- [ ] `sparkAdapter` address is immutable — not changeable in v1 (v2 adds governance-managed adapter registry)

### Harvesting
- [ ] `harvest()` — callable by anyone, executes the yield distribution cycle:
  - Calls `sparkAdapter.harvest()` (sole adapter in v1; v2 will loop over a registry)
  - Records total yield collected
  - Deducts protocol fee (`totalYield * feeRateBps / 10000`) → transfers to treasury
  - Deducts buffer contribution (`totalYield * bufferRateBps / 10000`) → deposits to `CircleBuffer`
  - Net yield remains in the pool; `totalAssets()` grows and every share's USDC value increases automatically — no per-position credit loop required
  - Emits `YieldHarvested(grossYield, protocolFee, bufferContribution, netYield, block.timestamp)`
- [ ] `harvest()` is idempotent within a single block — calling twice returns 0 on second call
- [ ] `harvest()` is callable no more than once per hour (prevents MEV griefing)

### Circuit Breaker (simplified for single adapter)
- [ ] Before every `harvest()`, check vault conversion rate via `sparkAdapter.getAPY()`:
  - If APY has dropped > 50% relative to the previous harvest window, emit `CircuitBreakerTripped(reason, timestamp)` and revert with `CircuitBreakerActive()` — pause new deposits only
  - Log circuit breaker state in emitted event
  - Withdrawals always available regardless of circuit breaker state
- [ ] No `rebalance()` function in v1 — single adapter means nothing to rebalance

### NatSpec

- [ ] All `public` and `external` functions have `@notice`, `@param`, and `@return` NatSpec tags
- [ ] Non-obvious logic (share price appreciation, circuit breaker thresholds, fee/buffer deduction) has `@dev` explanatory comments

### Security

- [ ] Contract inherits OpenZeppelin `ReentrancyGuard`
- [ ] `nonReentrant` modifier applied to all fund-moving external functions: `deposit()` (via `_deposit()`), `withdraw()` (via `_withdraw()`), `harvest()`

### Custom Errors

- [ ] `CircuitBreakerActive()` — revert when deposits/harvest blocked by circuit breaker
- [ ] `HarvestCooldownActive(uint256 nextAllowedAt)` — revert when `harvest()` called before the 1-hour cooldown expires
- [ ] `OnlySavingsAccount()` — revert when a non-SavingsAccount caller calls `deposit()`/`withdraw()`

### Fee Collection
- [ ] `feeRateBps` — configurable by governance, default 1000 (10%), hard ceiling 2000 (20%), hard floor 0
- [ ] `bufferRateBps` — configurable by governance, default 500 (5%), hard ceiling 1000 (10%)
- [ ] Treasury address configurable by governance with 7-day timelock
- [ ] `getFeeInfo() returns (uint256 feeRate, uint256 bufferRate, address treasury)` — public view

### APY
- [ ] `getBlendedAPY() returns (uint256 apyBps)`:
  - Returns `sparkAdapter.getAPY()` directly (single source, no weighting needed)
  - `getAPY()` on SparkUsdcVaultAdapter is derived from `rateProvider.getConversionRate()` delta between harvest windows

### Tests
- [ ] Unit tests at `backend/test/unit/YieldRouter.t.sol` using a mock SparkUsdcVaultAdapter:
  - Deposit 1000 USDC → mock adapter receives full amount
  - Harvest → gross yield collected, fee (10%) deducted, buffer (5%) deducted, share price rises
  - `harvest()` twice in one block → second call harvests 0 (idempotent)
  - Circuit breaker: mock adapter returns APY drop > 50% → `harvest()` paused, `withdraw()` still works
  - Withdrawal: correct USDC amount returned from adapter
  - PSM liquidity cap: mock `sparkAdapter.withdraw()` reverts with `InsufficientLiquidity` → YieldRouter calls `withdrawMax(assets)`, partial amount returned

---

## Output Files

- `backend/contracts/yield/YieldRouter.sol`
- `backend/test/unit/YieldRouter.t.sol`

---

## Notes

- Yield distribution is handled via share price appreciation (ERC4626 model) — no per-position distribution, no Merkle-drop. `harvest()` simply lets yield accumulate in the pool, raising `totalAssets()` and thus every share's USDC value automatically.
- `sparkAdapter` is set as an immutable address at construction in v1. v2 will introduce a governance-managed adapter registry.
- The YieldRouter is access-restricted: only `SavingsAccount` can call `deposit()` and `withdraw()`. The `onlySavingsAccount` modifier enforces this.
