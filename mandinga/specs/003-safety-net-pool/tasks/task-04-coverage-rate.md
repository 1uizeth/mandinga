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
  - Reverts `PositionInsolvent(shieldedId)` if `balance - circleObligation < remainder` (cannot charge from locked principal)
  - Emits `YieldCharged(shieldedId, amount, fromYield, fromBalance)`
- [ ] T002 Implement `chargeFromYield` in `contracts/src/core/SavingsAccount.sol` with `onlySafetyNetPool` modifier

### SafetyNetPool — accrual logic

- [ ] T003 Add `lastAccrualTs` to `GapCoverage` struct (defined in Task 003-02) in `contracts/src/core/SafetyNetPool.sol`:
  ```solidity
  struct GapCoverage {
      uint256 gapPerRound;
      uint256 totalDeployedShares;
      uint256 lastAccrualTs;       // ← new field
  }
  ```
  Set `lastAccrualTs = block.timestamp` on first `coverGap` call.

- [ ] T004 Implement `accrueInterest(uint256 circleId, uint16 slot) external` in `contracts/src/core/SafetyNetPool.sol`:
  ```
  elapsed   = block.timestamp - gapCoverages[circleId][slot].lastAccrualTs
  debtUsdc  = yieldRouter.convertToAssets(gapCoverages[circleId][slot].totalDeployedShares)
  interest  = debtUsdc × coverageRateBps × elapsed / (10_000 × 365 days)
  ```
  - If `interest == 0` (called too frequently), return early without writing state
  - Call `savingsAccount.chargeFromYield(memberId, interest)` using `ISavingsCircle(circle).getMember(circleId, slot)` to resolve `memberId`
  - Update `gapCoverages[circleId][slot].lastAccrualTs = block.timestamp`
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
      try savingsAccount.chargeFromYield(memberId, interest) {
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
  - `netUsdc = grossUsdc - debtUsdc - interestUsdc`

### ISafetyNetPool interface

- [ ] T009 Add `accrueInterest`, `getAccruedInterest`, `getEstimatedNetPayout` to `contracts/src/interfaces/ISafetyNetPool.sol` (created in Task 003-03)

### Tests

- [ ] T010 Unit test `test_accrueInterest_chargesYieldAfterTime` in `contracts/test/unit/SafetyNetPool.t.sol`:
  - Member has $40 gap covered for 30 days at 5% APY
  - `accrueInterest` charges ≈ $0.16 from member's yieldEarnedTotal
  - Verify `lastAccrualTs` updated
- [ ] T011 Unit test `test_accrueInterest_noopIfTooEarly` (called within MIN_ACCRUAL_INTERVAL)
- [ ] T012 Unit test `test_accrueInterest_chargesBalance_whenYieldInsufficient`:
  - Member's `yieldEarnedTotal = 0`, `balance - obligation` has sufficient free balance
  - Charge comes from balance, position remains solvent
- [ ] T013 Unit test `test_accrueInterest_revertsPositionInsolvent`:
  - Member has zero yield and zero withdrawable balance → `PositionInsolvent` revert
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

- **APY-linked rate (future):** to switch from fixed `coverageRateBps` to APY-linked,
  replace `coverageRateBps` in the interest formula with
  `yieldRouter.getBlendedAPY() + premiumBps`. No interface changes needed.
- **Interest as pool revenue:** the interest charged from members increases the pool's
  effective yield for depositors. In the current fungible model, this is implicit —
  the USDC charged from the member's position stays in the protocol and represents
  extra return. A cleaner model would route it explicitly to the pool's `totalCapital`,
  but this requires minting additional YieldRouter shares. For v1, track it via an
  `totalInterestCollected` accounting variable and add a `harvestInterest()` function
  for later.
- **`MockSavingsAccount`** needs a `chargeFromYield` stub and `yieldEarnedTotal` tracking
  for the new unit tests.
