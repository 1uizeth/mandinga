# Task 004-03b — Implement SparkUsdcVaultAdapter

**Spec:** 004 — Yield Engine
**Milestone:** 1
**Status:** Done ✓ — **sole yield adapter in v1**
**Estimated effort:** 5 hours
**Dependencies:** Task 004-01 (`IYieldSourceAdapter` interface)
**Parallel-safe:** Yes

---

## Objective

Implement `SparkUsdcVaultAdapter.sol` — a yield source adapter that deposits USDC into the Sky Savings Rate via `UsdcVaultL2` (Sky Protocol, Base), earns yield through sUSDS share price appreciation, and exposes the `IYieldSourceAdapter` interface consumed by `YieldRouter`.

---

## Context

`UsdcVaultL2` is a UUPS-upgradeable ERC4626 vault deployed on Base. It accepts USDC (6 dec), swaps it to sUSDS via Sky's PSM3, and holds sUSDS internally. Shares (`sUSDC`, 18 dec) are issued to depositors. Yield accrues silently as `rateProvider.getConversionRate()` increases over time — no explicit harvest call on the vault side. The adapter tracks USDC balance delta between harvest windows to compute yield earned.

**Decimal note:** `UsdcVaultL2.convertToAssets(shares)` always returns USDC in 6 decimals. The 1e12 internal scaling (USDC 6 dec ↔ sUSDS 18 dec) is handled by the PSM math inside the vault. The adapter never needs to normalise decimals.

**Liquidity cap note:** `vault.maxWithdraw(address(this))` is bounded by live USDC in the PSM pocket. The adapter must check this before every withdrawal and handle partial withdrawal gracefully.

See: Spec 004 v0.5, Clarifications Session 2026-03-04.

---

## Acceptance Criteria

### Interface (`IYieldSourceAdapter`)

`IYieldSourceAdapter` is defined and owned by **Task 004-01**. This task assumes it exists at `contracts/src/interfaces/IYieldSourceAdapter.sol`. Do not redefine it here.

### Core Adapter (`SparkUsdcVaultAdapter.sol`)

- [x] Contract at `contracts/src/yield/SparkUsdcVaultAdapter.sol` implementing `IYieldSourceAdapter`:

  **`deposit(uint256 amount)`**
  - `USDC.approve(address(vault), amount)`
  - `vault.deposit(amount, address(this))`
  - Updates `lastRecordedBalance += amount`

  **`withdraw(uint256 amount)`**
  - Checks `vault.maxWithdraw(address(this)) >= amount`; if not, reverts with `InsufficientLiquidity(available, requested)`
  - `vault.withdraw(amount, yieldRouter, address(this))`
  - Updates `lastRecordedBalance -= amount`

  **`getBalance() returns (uint256)`**
  - Returns `vault.convertToAssets(vault.balanceOf(address(this)))` — USDC (6 dec), no custom normalisation

  **`getAPY() returns (uint256)`**
  - Derived from `rateProvider.getConversionRate()` delta: `(currentRate - lastHarvestRate) * SECONDS_PER_YEAR / elapsed * 10000 / lastHarvestRate`
  - Returns value in basis points (10000 = 100%)
  - Returns 0 if called before first harvest window

  **`harvest() returns (uint256 yieldAmount)`**
  - `currentBalance = getBalance()`
  - `yieldAmount = currentBalance - lastRecordedBalance`
  - If `yieldAmount == 0`, return 0 (idempotent within same block)
  - `vault.withdraw(yieldAmount, yieldRouter, address(this))`
  - Updates `lastRecordedBalance = currentBalance - yieldAmount`
  - Updates `lastHarvestRate = rateProvider.getConversionRate()`
  - Updates `lastHarvestTimestamp = block.timestamp`
  - Emits `YieldHarvested(yieldAmount, block.timestamp)`

### Partial Withdrawal (PSM liquidity cap)

- [x] `withdrawMax(uint256 requested) returns (uint256 withdrawn)` — withdraws up to `vault.maxWithdraw(address(this))`; emits `PartialWithdrawal(requested, withdrawn)`. Updates `lastRecordedBalance -= withdrawn`. ✓

### Emergency Escape Hatch

- [x] `emergencyExit(address receiver)` — onlyOwner; calls `vault.exit(...)`; emits `EmergencyExit`; sets `paused = true`. ✓

### NatSpec

- [x] All `public` and `external` functions have NatSpec tags ✓
- [x] `@dev` comments for decimal handling and `lastRecordedBalance` delta ✓

### Security

- [x] Contract inherits OpenZeppelin `ReentrancyGuard` ✓
- [x] `nonReentrant` on all fund-moving functions ✓

### Constructor & Immutables

- [x] Constructor: `(address _vault, address _usdc, address _rateProvider, address _yieldRouter)` ✓
- [x] All four are `immutable` ✓
- [x] `onlyYieldRouter` modifier on `deposit()`, `withdraw()`, `withdrawMax()`, `harvest()` ✓
- [x] `onlyOwner` on `emergencyExit()` ✓

### Custom Errors

- [x] `InsufficientLiquidity(uint256 available, uint256 requested)` ✓
- [x] `AdapterPaused()` ✓
- [x] `ZeroAmount()` ✓

### Events

- [x] `YieldHarvested(uint256 yieldAmount, uint256 timestamp)` ✓
- [x] `PartialWithdrawal` (inherited from `IYieldSourceAdapter`) ✓
- [x] `EmergencyExit(uint256 sharesRedeemed, address receiver)` ✓

---

## Unit Tests (`test/unit/SparkUsdcVaultAdapter.t.sol`)

Tests run against a **Base Sepolia fork** (`forge test --fork-url $BASE_SEPOLIA_RPC_URL`).

- [x] **Deposit** — `test_deposit_transfersUsdcToVault`, `test_deposit_updatesLastRecordedBalance` ✓
- [x] **Yield accrual** — `test_getBalance_increasesWithYield` (via `vault.accrueYield()`) ✓
- [x] **Harvest** — `test_harvest_transfersYieldToYieldRouter`, `test_harvest_updatesLastRecordedBalance`, `test_harvest_updatesRateAndTimestamp` ✓
- [x] **Harvest idempotency** — `test_harvest_idempotentWithinSameBlock` ✓
- [x] **Withdraw** — `test_withdraw_returnsUsdcToYieldRouter` ✓
- [x] **PSM liquidity cap** — `test_withdraw_revertsIfPsmCapInsufficient`, `test_withdrawMax_partialWhenPsmCapped` ✓
- [x] **`getAPY()`** — `test_getAPY_nonZeroAfterHarvestWindow` ✓
- [x] **Emergency exit** — `test_emergencyExit_revertsIfNotOwner`, `test_emergencyExit_pausesAdapter`, `test_emergencyExit_transfersToReceiver`, `test_emergencyExit_emitsEvent` ✓

> All 22 tests in `test/unit/SparkUsdcVaultAdapter.t.sol` pass against mock vault (no fork required).
> Fork-based tests against Base Sepolia `UsdcVaultL2` proxy can be added with `$BASE_SEPOLIA_RPC_URL`.

---

## Output Files

- `contracts/src/yield/SparkUsdcVaultAdapter.sol`
- `test/unit/SparkUsdcVaultAdapter.t.sol`

---

## Contract Addresses (Base Sepolia testnet)

| Contract | Address |
|---|---|
| UsdcVaultL2 Proxy | `0x4d5158F47E489a60bCaA8CD8F06B14A143E4043D` |
| MockUSDC | `0x996C4ae5897bE0c1D89F4AD857d64F403b11bFb2` |
| MockSUSDS | `0x1339Ad362bAc438e885f535966127Ae03fC09002` |
| MockRateProvider | `0xaCa48d64e88E9812BdCCa1F156418E25Fd6C656D` |
| MockPSM | `0x8E1913834955E004c342a00cc38C3dFF53FCc46e` |

> Always interact with the **Proxy** address. The implementation may be upgraded by Sky governance.

---

## Notes

- Do NOT use the deprecated `deposit()` variant; always use `vault.deposit(amount, address(this))` (standard ERC4626)
- `harvest()` must be idempotent — calling twice in the same block returns 0 on the second call (no state mutation)
- `getBalance()` is a pure read — it never moves funds; use `convertToAssets(balanceOf(this))` only
- All USDC amounts use 6 decimals; all share amounts use 18 decimals — never mix them in accounting
- Set `$BASE_SEPOLIA_RPC_URL` in your `.env` file for fork tests
- `rateProvider.getConversionRate()` returns a ray (1e27 precision) — normalise when computing APY basis points
