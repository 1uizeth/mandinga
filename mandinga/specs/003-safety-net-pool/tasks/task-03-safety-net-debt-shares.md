# Task 003-03 — safetyNetDebtShares: Atomic Debt Settlement at Selection

**Spec:** 003 — Safety Net Pool (v1.0) — US-004
**Milestone:** 5
**Status:** Pending
**Estimated effort:** 8 hours
**Dependencies:** Task 003-02 (minDepositPerRound + safetyNetDebtShares field)
**Parallel-safe:** No

> **Privacy assumption:** Same as Task 003-02 — OQ-004 deferred. Settlement reads
> `safetyNetDebtShares` directly from `ISavingsAccount` without ZK proof.

---

## Objective

When a min-installment member is selected for payout by Chainlink VRF, the Safety Net
Pool debt accumulated over previous rounds (`safetyNetDebtShares`) is **settled
atomically** in the same transaction as the payout credit — before
`circleObligationShares` is set. This ensures:

1. The pool releases the capital it had committed to cover this member's gaps.
2. The member's net obligation is reduced by the debt amount (not their payout balance).
3. After settlement, `safetyNetDebtShares` is reset to zero.

The spec guarantees this is always solvent: the gross payout (`N × depositPerRound`) is
always ≥ maximum possible debt (`N × gap`) because `minDepositPerRound > 0`.

---

## Context

### Current `_processPayout` flow (SavingsCircle.sol, lines 288–306)

```
1. setCircleObligation(memberId, poolSize)   ← locks full payout
2. creditPrincipal(memberId, poolSize)        ← credits full payout
3. payoutReceived[circleId][slot] = true
```

### Target flow after this task

```
1. Read safetyNetDebtShares = savingsAccount.getSafetyNetDebtShares(memberId)
2. If debt > 0:
   a. Convert debt shares → USDC: debtUsdc = pool.convertDebtToUsdc(debtShares)
   b. pool.settleGapDebt(circleId, slot)     ← releases totalDeployed, clears pool-side tracking
   c. savingsAccount.clearSafetyNetDebt(memberId)   ← resets safetyNetDebtShares to 0
   d. netObligation = poolSize - debtUsdc            ← reduced obligation (debt already pre-paid)
3. setCircleObligation(memberId, netObligation)
4. creditPrincipal(memberId, poolSize)               ← full credit always (spec AC-004-3)
5. payoutReceived[circleId][slot] = true
```

---

## Acceptance Criteria

### ISavingsAccount / SavingsAccount — new functions

- [ ] T001 [P] Add `clearSafetyNetDebt(bytes32 shieldedId)` to `ISavingsAccount` interface in `contracts/src/interfaces/ISavingsAccount.sol`
  - Callable only by `SavingsCircle`; resets `safetyNetDebtShares` to 0
  - Emits `SafetyNetDebtCleared(shieldedId, settledShares)`
- [ ] T002 Implement `clearSafetyNetDebt` in `contracts/src/core/SavingsAccount.sol` with `onlySavingsCircle` modifier

### SafetyNetPool — debt settlement

- [ ] T003 [P] Add `settleGapDebt(uint256 circleId, uint16 slot) external onlyCircle` to `contracts/src/core/SafetyNetPool.sol`:
  - Reads `gapCoverages[circleId][slot].totalDeployed`
  - Decrements `totalDeployed` by that amount
  - Deletes `gapCoverages[circleId][slot]`
  - Emits `GapDebtSettled(circleId, slot, amountReleased)`
  - Reverts `GapNotFound(circleId, slot)` if no gap coverage exists for this slot
- [ ] T004 [P] Add `convertGapToUsdc(uint256 circleId, uint16 slot) external view returns (uint256)` to `contracts/src/core/SafetyNetPool.sol`:
  - Returns `yieldRouter.convertToAssets(gapCoverages[circleId][slot].totalDeployedShares)`
  - Used by `SavingsCircle._processPayout` to compute `debtUsdc`

### SavingsCircle — two-phase payout split (CHK039 resolution)

> **Architectural decision:** debt settlement is gas-heavy (settleGapDebt + clearSafetyNetDebt +
> _accrueInterestInternal + chargeFromYield). Moving it inside `fulfillRandomWords` risks
> exceeding `CALLBACK_GAS_LIMIT = 300_000`. The solution is a **two-phase split**:
>
> - **Phase 1 (VRF callback, lightweight):** mark the winner; no settlement.
> - **Phase 2 (separate tx, `claimPayout`):** full settlement called by the member or a keeper.

- [ ] T005 Add `pendingPayout` mapping to `contracts/src/core/SavingsCircle.sol`:
  ```solidity
  mapping(uint256 circleId => mapping(uint16 slot => bool)) public pendingPayout;
  ```
  and new event `MemberSelected(uint256 indexed circleId, uint16 slot, bytes32 shieldedId)`.

- [ ] T006 Modify `fulfillRandomWords` in `contracts/src/core/SavingsCircle.sol` to call a
  new lightweight `_markPayout(circleId, selectedSlot)` internal instead of `_processPayout`:
  ```solidity
  function _markPayout(uint256 circleId, uint16 slot) internal {
      pendingPayout[circleId][slot] = true;
      payoutReceived[circleId][slot] = true;   // keeps eligibility logic unchanged
      circles[circleId].roundsCompleted++;
      emit MemberSelected(circleId, slot, _members[circleId][slot]);
      if (circles[circleId].roundsCompleted == circles[circleId].memberCount) {
          _completeCircle(circleId);
      }
  }
  ```
  Gas budget of `fulfillRandomWords` after this change: ≤ 150,000 (within the 300,000 limit).

- [ ] T007 Implement `claimPayout(uint256 circleId) external nonReentrant` in
  `contracts/src/core/SavingsCircle.sol` — callable by anyone (permissionless, like `executeRound`):
  1. Resolve `slot` from `savingsAccount.computeShieldedId(msg.sender)` → match in `_members[circleId]`
     **OR** accept `uint16 slot` parameter and verify `_members[circleId][slot] == computeShieldedId(msg.sender)` (preferred — avoids O(N) loop)
  2. Require `pendingPayout[circleId][slot] == true`; revert `NoPendingPayout(circleId, slot)` otherwise
  3. Run full settlement:
     - Read `debtShares = savingsAccount.getSafetyNetDebtShares(memberId)`
     - If `debtShares > 0`: `debtUsdc = pool.convertGapToUsdc(circleId, slot)`, `pool.settleGapDebt(circleId, slot)`, `savingsAccount.clearSafetyNetDebt(memberId)`
     - `setCircleObligation(memberId, poolSize - debtUsdc)`
     - `creditPrincipal(memberId, poolSize)`
  4. Clear `pendingPayout[circleId][slot] = false`
  5. Emit `PayoutSettled(circleId, slot, poolSize, debtUsdc, poolSize - debtUsdc)`

- [ ] T008 Verify net obligation invariant in `claimPayout`: revert `DebtExceedsPayout(debtUsdc, poolSize)` if `debtUsdc > poolSize` as safety guard

- [ ] T009 Emit `PayoutSettled(uint256 indexed circleId, uint16 slot, uint256 grossPayout, uint256 debtUsdc, uint256 netObligation)` event (AC-004-6 — member breakdown)

### SavingsCircle — reference to pool

- [ ] T010 Add `ISafetyNetPool pool` immutable to `SavingsCircle` constructor (or cast `buffer` to a richer interface) — needed for `settleGapDebt` and `convertGapToUsdc` calls in `contracts/src/core/SavingsCircle.sol`
- [ ] T011 Create `contracts/src/interfaces/ISafetyNetPool.sol` with the minimum surface needed by SavingsCircle: `settleGapDebt`, `convertGapToUsdc`, `coverGap`, `coverSlot`, `releaseSlot`; have `SafetyNetPool` implement it

### Tests

- [ ] T012 Unit test `test_fulfillRandomWords_onlyMarksPayout_doesNotSettle` in `contracts/test/unit/SavingsCircle.t.sol`:
  - After VRF callback: `pendingPayout[circleId][slot] == true`, `payoutReceived == true`
  - `circleObligation` unchanged (settlement deferred), `balance` unchanged
  - Gas usage of VRF callback stays ≤ 150,000
- [ ] T013 Unit test `test_claimPayout_noDebt_fullObligation` — member with no debt claims full obligation
- [ ] T014 Unit test `test_claimPayout_withDebt_reducedObligation`:
  - Member accumulated 2 rounds × shares($40) debt
  - After claim: `circleObligation = poolSize - $80`, `safetyNetDebtShares = 0`, pool `totalDeployed` reduced by $80
- [ ] T015 Unit test `test_claimPayout_debtExceedsPayout_reverts` (safety guard T008)
- [ ] T016 Unit test `test_claimPayout_revertsIfNoPendingPayout`
- [ ] T017 Unit test `test_settleGapDebt_revertsGapNotFound` in `contracts/test/unit/SafetyNetPool.t.sol`
- [ ] T018 Unit test `test_clearSafetyNetDebt_revertsIfNotCircle` in `contracts/test/unit/SavingsAccount.t.sol`
- [ ] T019 Integration test `test_minInstallment_selectionSettlesDebt` in `contracts/test/integration/MinInstallmentIntegration.t.sol`:
  - 3-member circle, member A uses min installment over 2 rounds before selection
  - VRF fires → `pendingPayout[circleId][0] = true`, NO obligation set yet
  - A calls `claimPayout(circleId, 0)` → debt cleared, obligation is net, pool `totalDeployed = 0`
  - Remaining members (B, C) unaffected: full obligation preserved

---

## Output Files

- `contracts/src/interfaces/ISavingsAccount.sol` (modified — `clearSafetyNetDebt`)
- `contracts/src/interfaces/ISafetyNetPool.sol` (new — combined pool interface for SavingsCircle)
- `contracts/src/core/SavingsAccount.sol` (modified — `clearSafetyNetDebt`)
- `contracts/src/core/SavingsCircle.sol` (modified — `_markPayout`, `claimPayout`, `pendingPayout` mapping, new pool reference)
- `contracts/src/core/SafetyNetPool.sol` (modified — `settleGapDebt`, `convertGapToUsdc`)
- `contracts/test/unit/SavingsCircle.t.sol` (modified — two-phase payout tests)
- `contracts/test/unit/SafetyNetPool.t.sol` (modified — settleGapDebt tests)
- `contracts/test/integration/MinInstallmentIntegration.t.sol` (extended)

---

## Key Invariants

- **Two-phase payout (CHK039):** `fulfillRandomWords` only marks the winner — it never
  writes obligation or credits balance. All state-heavy settlement happens in `claimPayout`.
  This keeps the VRF callback gas budget ≤ 150,000 (well within `CALLBACK_GAS_LIMIT = 300,000`).
- **`payoutReceived` set in Phase 1:** the eligibility flag is set in `_markPayout` (VRF callback)
  to prevent the same slot from being selected again before `claimPayout` is called.
- **`pendingPayout` cleared in Phase 2:** `claimPayout` is the only place that performs
  settlement; calling it twice reverts with `NoPendingPayout`.
- **Full credit always:** `creditPrincipal(memberId, poolSize)` is never reduced — only
  the *obligation* (locked portion) is reduced by debt.
- **Solvency guarantee (spec AC-004-3):** `debtUsdc ≤ poolSize` always holds. The guard
  in T008 is belt-and-suspenders.
- **Backward compat:** members with `safetyNetDebtShares == 0` go through the same
  `claimPayout` path — settlement is a no-op and the result is identical to the old
  `_processPayout` (T013 test).

---

## Notes

- `ISafetyNetPool` (T009) should replace `ICircleBuffer` as the immutable in
  `SavingsCircle` — `ISafetyNetPool` can extend `ICircleBuffer` so no existing
  call sites break.
- The `MockSafetyNetPool` in tests needs updating: add stub implementations of
  `settleGapDebt` and `convertGapToUsdc`.
- `gapCoverages[circleId][slot].totalDeployedShares` must track shares (not raw USDC)
  to correctly reflect yield appreciation at settlement time. Revise the `GapCoverage`
  struct from Task 003-02 to store `totalDeployedShares uint256` alongside `gapPerRound`.
