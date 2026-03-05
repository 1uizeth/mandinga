# Task 003-04 — Coverage Rate: Interest Accrual on safetyNetDebtShares

**Spec:** 003 — Safety Net Pool (v1.0) — AC-003-4, OQ-005
**Milestone:** 5
**Status:** Pending
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

- [ ] T001 [P] Add `chargeFromYield(bytes32 shieldedId, uint256 amount) external` to `ISavingsAccount` interface in `contracts/src/interfaces/ISavingsAccount.sol`:
  - Callable only by `SafetyNetPool`
  - Deducts `amount` from `yieldEarnedTotal` first; if insufficient, remainder from `balance`
  - **Explicit (CHK013):** `circleObligation` is **excluded** from available balance. Only
    `balance - circleObligation` (the withdrawable portion) can be charged from balance.
    If `balance - circleObligation < remainder`, revert `PositionInsolvent(shieldedId)`.
  - Emits `YieldCharged(shieldedId, amount, fromYield, fromBalance)` where `fromYield + fromBalance == amount`
- [ ] T002 Implement `chargeFromYield` in `contracts/src/core/SavingsAccount.sol` with `onlySafetyNetPool` modifier

### SafetyNetPool — accrual logic

- [ ] T003 `GapCoverage.lastAccrualTs` is already declared in the canonical struct defined in **Task 003-02 T012**. No struct redefinition is needed here.
  Verify that `coverGap` (Task 003-02 T013) sets `lastAccrualTs = block.timestamp` on the **first** call for a slot (i.e., when `gapCoverages[circleId][slot].lastAccrualTs == 0`).

- [ ] T004 Implement `accrueInterest(uint256 circleId, uint16 slot) external` in `contracts/src/core/SafetyNetPool.sol`:
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

- [ ] T005 Make `accrueInterest` permissionless (callable by anyone) — consistent with how
  Aave/Compound accrue interest. Add a `minElapsed` guard (e.g., 1 hour) to prevent gas
  waste from too-frequent calls. Store `MIN_ACCRUAL_INTERVAL = 1 hours` constant.

- [ ] T006 Add `_accrueInterestInternal(uint256 circleId, uint16 slot)` private helper in
  `contracts/src/core/SafetyNetPool.sol` and call it at the start of `settleGapDebt`.
  **This helper MUST NOT revert** — `settleGapDebt` is called from `SavingsCircle.claimPayout`
  which originates in the VRF callback chain; a revert would stall the circle permanently.
  Required implementation pattern:
  ```solidity
  function _accrueInterestInternal(uint256 circleId, uint16 slot) private {
      uint256 interest = _computeInterest(circleId, slot);
      if (interest == 0) return;
      bytes32 memberId = _getMember(circleId, slot);
      try {
          savingsAccount.chargeFromYield(memberId, interest);
          gapCoverages[circleId][slot].lastAccrualTs = block.timestamp;
          emit InterestAccrued(circleId, slot, memberId, interest);
      } catch {
          // Position insolvent at settlement time — interest is forgiven.
          // lastAccrualTs is NOT updated so outstanding interest remains
          // visible via getAccruedInterest() for accounting purposes.
          emit InterestForgiven(circleId, slot, memberId, interest);
      }
  }
  ```
  - Add `InterestForgiven(uint256 indexed circleId, uint16 indexed slot, bytes32 memberId, uint256 amount)` event to `contracts/src/core/SafetyNetPool.sol`
  - The `try/catch` pattern is mandatory — omitting it violates the no-revert invariant of the payout path

### View helpers

- [ ] T007 [P] Add `getAccruedInterest(uint256 circleId, uint16 slot) external view returns (uint256 usdc)` to `contracts/src/core/SafetyNetPool.sol`:
  - Read-only calculation of outstanding interest since last accrual
  - Used by the frontend to display "estimated net payout at current APY" (AC-003-5)

- [ ] T008 [P] Add `getEstimatedNetPayout(uint256 circleId, uint16 slot) external view returns (uint256 grossUsdc, uint256 debtUsdc, uint256 interestUsdc, uint256 netUsdc)` to `contracts/src/core/SafetyNetPool.sol`:
  - `grossUsdc = circles[circleId].poolSize`
  - `debtUsdc = convertToAssets(gapCoverages[circleId][slot].totalDeployedShares)`
  - `interestUsdc = getAccruedInterest(circleId, slot)`
  - **Underflow guard (CHK004):** `netUsdc = debtUsdc + interestUsdc >= grossUsdc ? 0 : grossUsdc - debtUsdc - interestUsdc`
    (floor at 0; the solvency guarantee prevents this in production, but it is possible in
    adversarial test scenarios where yield exceeds the pool size)

### ISafetyNetPool interface

- [ ] T009 Add `accrueInterest`, `getAccruedInterest`, `getEstimatedNetPayout` to `contracts/src/interfaces/ISafetyNetPool.sol` (created in Task 003-03)

### Tests

- [ ] T010 Unit test `test_accrueInterest_chargesYieldAfterTime` in `contracts/test/unit/SafetyNetPool.t.sol`:
  - Member has $40 USDC (= 40_000_000 units) gap covered for 30 days at 5% APY (500 bps)
  - Exact expected value (CHK023):
    ```
    elapsed  = 30 × 86400 = 2_592_000 seconds
    interest = 40_000_000 × 500 × 2_592_000 / (10_000 × 365 × 86400)
             = 51_840_000_000_000_000 / 315_360_000_000
             = 164_383 (USDC 6-decimal units, integer truncation)
    ```
    `assertEq(interest, 164_383)` — no tolerance/approximation; integer division is deterministic
  - Verify `lastAccrualTs` updated, `totalInterestCollected == 164_383`
- [ ] T011 Unit test `test_accrueInterest_noopIfTooEarly` (called within MIN_ACCRUAL_INTERVAL)
- [ ] T012 Unit test `test_accrueInterest_chargesBalance_whenYieldInsufficient`:
  - Member's `yieldEarnedTotal = 0`, `balance - obligation` has sufficient free balance
  - Charge comes from balance, position remains solvent
- [ ] T013 Unit test `test_accrueInterest_revertsPositionInsolvent` (CHK024):
  - Member has `yieldEarnedTotal = 0` and `balance = circleObligation` (zero withdrawable)
  - External call `accrueInterest` reverts with `PositionInsolvent` (propagated to caller)
  - Note: `_accrueInterestInternal` (called from `settleGapDebt`) uses `try/catch` and does NOT
    propagate this revert — that behavior is covered by T017
- [ ] T014 Unit test `test_chargeFromYield_revertsIfNotPool` in `contracts/test/unit/SavingsAccount.t.sol`
- [ ] T015 Unit test `test_settleGapDebt_accruesInterestFirst` — verifies auto-accrual in T006
- [ ] T017 Unit test `test_accrueInterestInternal_forgivesInterest_whenPositionInsolvent`:
  - Member has `yieldEarnedTotal = 0` and `balance = circleObligation` (zero withdrawable)
  - `settleGapDebt` is called (triggers `_accrueInterestInternal`)
  - Interest accrual fails silently: `InterestForgiven` event emitted, `InterestAccrued` NOT emitted
  - Settlement proceeds normally: `GapDebtSettled` event emitted, `totalDeployed` decremented
  - Circle is NOT stalled — no revert propagated
- [ ] T016 Integration test `test_minInstallment_interestAccrues_thenSettles` in `contracts/test/integration/MinInstallmentIntegration.t.sol`:
  - Member A uses min installment for 3 rounds (60 days total)
  - `accrueInterest` called at day 30 and day 60
  - A is selected: debt + accrued interest both cleared atomically
  - A's net obligation = `poolSize - debtUsdc - totalInterest`
  - Pool depositor's effective yield includes the interest received

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
