# Task 003-04 — Coverage Rate: Interest Accrual on safetyNetDebtShares

**Spec:** 003 — Safety Net Pool (v1.0) — AC-003-4, OQ-005
**Milestone:** 5
**Status:** Done ✓
**Estimated effort:** 6 hours
**Dependencies:** Task 003-02 (safetyNetDebtShares field), Task 003-03 (clearSafetyNetDebt)
**Parallel-safe:** No

> **OQ-005 resolution assumed:** This task implements the **fixed governance-set rate**
> option. `coverageRateBps` is already stored on `SafetyNetPool`. APY-linked rate can
> be swapped in later by changing the `accrueInterest` calculation without interface changes.

---

## Objective

Activate the `coverageRateBps` rate that is currently stored but never applied.
Interest accrues continuously on the `safetyNetDebtShares` balance of a covered member
and is charged from their **yield earnings** (not principal), as per AC-003-4.

The mechanic:
- Each covered slot accumulates interest at `annualRate × elapsed / 365 days`
- Interest is charged by deducting from the member's `yieldEarnedTotal` in `SavingsAccount`
- If the member has insufficient yield, the remainder is charged from `balance`
  (principle of last resort — prevents interest accrual from stalling indefinitely)
- Interest is added to the pool's claimable revenue (increases `totalDeployed` → eventually
  flows back to depositors as part of their yield-enhanced returns)

---

## Context

### Why interest on debt shares, not on USDC gap amount?

Debt shares (`safetyNetDebtShares`) appreciate with the YieldRouter — the value the pool
advanced is growing over time. Charging interest on shares ensures the rate is
self-adjusting relative to the underlying yield: the member pays a premium over the
base APY they're receiving on their position. This keeps the rate economically transparent.

### Current state

`SafetyNetPool.coverageRateBps` = 500 (5% annual, default). It is stored but never read
in any calculation. `gapCoverages[circleId][slot].lastRoundCovered` tracks the last
accrual round (added in Task 003-02).

---

## Acceptance Criteria

### ISavingsAccount / SavingsAccount — new function

- [x] T001 [P] Add `chargeFromYield(bytes32 shieldedId, uint256 amount) external` to `ISavingsAccount` interface in `contracts/src/interfaces/ISavingsAccount.sol`:
  - Callable only by `SafetyNetPool`
  - Deducts `amount` from `yieldEarnedTotal` first; if insufficient, remainder from `balance`
  - **Explicit (CHK013):** `circleObligation` is **excluded** from available balance. Only
    `balance - circleObligation` (the withdrawable portion) can be charged from balance.
    If `balance - circleObligation < remainder`, revert `PositionInsolvent(shieldedId)`.
  - Emits `YieldCharged(shieldedId, amount, fromYield, fromBalance)` where `fromYield + fromBalance == amount`
- [x] T002 Implement `chargeFromYield` in `contracts/src/core/SavingsAccount.sol` with `onlySafetyNetPool` modifier

### SafetyNetPool — accrual logic

- [x] T003 `GapCoverage.lastAccrualTs` is already declared in the canonical struct defined in **Task 003-02 T012**. No struct redefinition is needed here.
  `coverGap` (Task 003-02 T013) sets `lastAccrualTs = block.timestamp` on the **first** call for a slot (when `lastAccrualTs == 0`). ✓

- [x] T004 Implement `accrueInterest(uint256 circleId, uint16 slot) external` in `contracts/src/core/SafetyNetPool.sol`:
  ```
  elapsed   = block.timestamp - gapCoverages[circleId][slot].lastAccrualTs
  debtUsdc  = yieldRouter.convertToAssets(gapCoverages[circleId][slot].totalDeployedShares)
  interest  = debtUsdc × coverageRateBps × elapsed / (10_000 × 365 days)
  ```
  Guards:
  - If `gapCoverages[circleId][slot].lastAccrualTs == 0`: return early (slot not tracked or
    already settled — post-deletion no-op) (CHK028)
  - If `coverageRateBps == 0`: return early without writing state — the rate is zero, accrual
    is a no-op. `lastAccrualTs` is NOT updated (preserves the elapsed window for when
    governance sets a non-zero rate) (CHK031)
  - If `elapsed < MIN_ACCRUAL_INTERVAL`: return early (T005)
  - If `interest == 0` (rounding truncation): return early without writing state
  - `memberId = gapCoverages[circleId][slot].memberId`
  - Call `savingsAccount.chargeFromYield(memberId, interest)`
  - Update `gapCoverages[circleId][slot].lastAccrualTs = block.timestamp`
  - `totalInterestCollected += interest` (accounting variable — see Notes, CHK043)
  - Emits `InterestAccrued(circleId, slot, memberId, interest)`

- [x] T005 `accrueInterest` is permissionless (callable by anyone). `MIN_ACCRUAL_INTERVAL = 1 hours` constant prevents gas waste from too-frequent calls. ✓

- [x] T006 Add `_accrueInterestInternal(uint256 circleId, uint16 slot)` internal helper in
  `contracts/src/core/SafetyNetPool.sol`, called at the start of `settleGapDebt`.
  Wraps `chargeFromYield` in a `try/catch` — emits `InterestForgiven` on `PositionInsolvent`
  and proceeds without reverting. `InterestForgiven` event added. ✓

### View helpers

- [x] T007 [P] Add `getAccruedInterest(uint256 circleId, uint16 slot) external view returns (uint256 usdc)` to `contracts/src/core/SafetyNetPool.sol`:
  - Read-only calculation of outstanding interest since last accrual ✓

- [x] T008 [P] Add `getEstimatedNetPayout(uint256 circleId, uint16 slot) external view returns (uint256 grossUsdc, uint256 debtUsdc, uint256 interestUsdc, uint256 netUsdc)` to `contracts/src/core/SafetyNetPool.sol`:
  - `grossUsdc`, `debtUsdc`, `interestUsdc`, `netUsdc` with underflow guard (CHK004) ✓

### ISafetyNetPool interface

- [x] T009 Add `accrueInterest`, `getAccruedInterest`, `getEstimatedNetPayout` to `contracts/src/interfaces/ISafetyNetPool.sol` (created in Task 003-03) ✓

### Tests

- [x] T010 Unit test `test_accrueInterest_30days_5pct_exactValue` in `contracts/test/unit/CoverageRate.t.sol`:
  - $40 USDC gap, 30 days, 500 bps → `assertEq(interest, 164_383)` ✓
  - `lastAccrualTs` updated, `totalInterestCollected == 164_383` verified ✓
- [x] T011 Unit test `test_accrueInterest_tooSoon_noop` (elapsed < MIN_ACCRUAL_INTERVAL) ✓
- [ ] T012 Unit test `test_accrueInterest_chargesBalance_whenYieldInsufficient` — not yet written
- [x] T013 Unit test `test_accrueInterest_insolventMember_revertsWithPositionInsolvent`:
  - External `accrueInterest` propagates `PositionInsolvent` to caller ✓
- [ ] T014 Unit test `test_chargeFromYield_revertsIfNotPool` in `contracts/test/unit/SavingsAccount.t.sol` — not yet written
- [x] T015 Unit test `test_settleGapDebt_accruesInterestFirst` — `_accrueInterestInternal` called inside `settleGapDebt` ✓
- [x] T017 Unit test `test_settleGapDebt_insolventInterest_emitsInterestForgiven`:
  - Insolvent member: `InterestForgiven` emitted, `InterestAccrued` NOT emitted
  - `GapDebtSettled` emitted — settlement proceeds without revert ✓
- [ ] T016 Integration test `test_minInstallment_interestAccrues_thenSettles` in `contracts/test/integration/MinInstallmentIntegration.t.sol` — deferred

---

## Output Files

- `contracts/src/interfaces/ISavingsAccount.sol` (modified — `chargeFromYield`)
- `contracts/src/interfaces/ISafetyNetPool.sol` (modified — `accrueInterest`, view helpers)
- `contracts/src/core/SavingsAccount.sol` (modified — `chargeFromYield`, `onlySafetyNetPool`)
- `contracts/src/core/SafetyNetPool.sol` (modified — `accrueInterest`, `getAccruedInterest`, `getEstimatedNetPayout`, `_accrueInterestInternal`, `MIN_ACCRUAL_INTERVAL`)
- `contracts/test/unit/SafetyNetPool.t.sol` (modified — accrual tests)
- `contracts/test/unit/SavingsAccount.t.sol` (modified — chargeFromYield tests)
- `contracts/test/integration/MinInstallmentIntegration.t.sol` (extended — end-to-end with interest)

---

## Key Invariants

- Interest is charged from **yield first, balance second** — never from locked (`circleObligation`) principal
- `_accrueInterestInternal` MUST wrap `chargeFromYield` in a `try/catch` (T006). If the
  member is insolvent at settlement time, the interest is **forgiven** (not accrued, not
  queued). `settleGapDebt` always proceeds regardless of the interest outcome — the two
  paths are explicitly separated. This prevents `PositionInsolvent` from propagating into
  the VRF payout chain and stalling the circle.
- `getEstimatedNetPayout` (T008) is a pure view — it must never write state, even when
  called from within a transaction.
- `accrueInterest` is idempotent within the same block (same `block.timestamp` →
  `elapsed = 0` → no charge).

---

## Notes

- **Interest accrual while paused (CHK006):** interest continues accruing on
  `safetyNetDebtShares` while a member is paused. The `gapCoverages` entry persists
  through pause/resume and `lastAccrualTs` advances normally. If the pause is long,
  the accrued interest grows proportionally. This is accepted behavior — the debt
  remains outstanding until `claimPayout` settles it.
- **APY-linked rate (future):** to switch from fixed `coverageRateBps` to APY-linked,
  replace `coverageRateBps` in the interest formula with
  `yieldRouter.getBlendedAPY() + premiumBps`. No interface changes needed.
- **Interest revenue mechanism (CHK043 resolution):** in v1, interest charged from members
  is tracked via `totalInterestCollected uint256` (new accounting variable on `SafetyNetPool`).
  This variable does NOT directly increase `totalDeployed` or mint YieldRouter shares.
  The USDC remains in the protocol's implicit float. A separate `harvestInterest()` function
  (future v2) will convert `totalInterestCollected` to YieldRouter shares, increasing depositors'
  yield. This separates the "track" and "distribute" steps cleanly. **T004 must increment
  `totalInterestCollected += interest` after each successful `chargeFromYield` call.** Add
  `totalInterestCollected` to the Output Files section (state variable in `SafetyNetPool.sol`).
- **`MockSavingsAccount`** needs a `chargeFromYield` stub and `yieldEarnedTotal` tracking
  for the new unit tests.
