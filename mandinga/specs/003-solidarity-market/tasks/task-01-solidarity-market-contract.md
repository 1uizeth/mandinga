# Task 003-01 — Implement SolidarityMarket Contract

**Spec:** 003 — Solidarity Market
**Milestone:** 4
**Status:** Blocked on Milestone 3 (SavingsCircle complete and tested)
**Estimated effort:** 14 hours
**Dependencies:** Task 002-01 (SavingsCircle), Task 001-02 (SavingsAccount)
**Parallel-safe:** No

---

## Objective

Implement `SolidarityMarket.sol` — the peer vouching layer. Manages vouch creation, locking, income accrual (interest + payout share), and expiry/renewal.

---

## Context

The Solidarity Market sits on top of the savings account and savings circle. A vouch is an economic relationship: the voucher locks capital in their savings account as backing for another member, earns passive income, and benefits when that member is selected for a payout.

See: Spec 003 all user stories, plan.md §3.3.

---

## Acceptance Criteria

### Contract Structure
- [ ] Contract at `contracts/core/SolidarityMarket.sol`
- [ ] Constructor takes: `ISavingsAccount savingsAccount`, `ISavingsCircle savingsCircle`
- [ ] Emits `SavingsCircle.MemberSelected` event to trigger payout share distribution (implement as a listener via `savingsCircle.registerPayoutListener(address(this))` or equivalent callback pattern)

### Vouch Creation
- [ ] `createVouch(bytes32 vouchedId, uint256 amount, uint256 interestRateBps, uint256 payoutShareBps, uint256 circleId) returns (uint256 vouchId)`:
  - Validates voucher's withdrawable balance >= `amount`
  - Validates total vouched amount (all active vouches) <= 80% of voucher's total balance
  - Validates `payoutShareBps` is between 1000 (10%) and 5000 (50%) — prevents exploitative splits
  - Validates `circleId` exists and is ACTIVE
  - Increases voucher's `circleObligation` by `amount` (locks the vouch amount)
  - Records vouch in `vouches` mapping
  - Emits `VouchCreated(vouchId, voucherId, vouchedId, amount, circleId)`
- [ ] `acceptVouch(uint256 vouchId, bytes calldata historyProof)`:
  - Callable only by the intended `vouchedId` member
  - Verifies `historyProof` (ZK proof of savings history — can be a mock in v1)
  - Joins the vouched member to the associated circle with the combined balance
  - Sets vouch status to `ACTIVE`
  - Emits `VouchAccepted(vouchId)`

### Interest Accrual
- [ ] `accrueInterest(uint256 vouchId)` — callable by anyone, updates interest:
  - Calculates interest as `amount * interestRateBps * timeSinceLastAccrual / (10000 * 365 days)`
  - Adds accrued interest to `vouches[vouchId].pendingInterest`
  - Updates `lastAccrualTimestamp`
- [ ] `claimInterest(uint256 vouchId)`:
  - Callable only by voucher
  - Transfers `pendingInterest` from vouched member's yield earnings to voucher's balance
  - Requires vouched member's balance to have sufficient yield (not principal)
  - Resets `pendingInterest` to 0
  - Emits `InterestClaimed(vouchId, amount)`

### Payout Share Distribution
- [ ] `onMemberSelected(uint256 circleId, bytes32 selectedMemberId)` — called by SavingsCircle on payout:
  - Looks up any active vouch for `selectedMemberId` in `circleId`
  - Calculates payout share: `yieldLeveragePremium * payoutShareBps / 10000`
  - Credits share to voucher's balance
  - Emits `PayoutShareDistributed(vouchId, amount)`

### Vouch Expiry
- [ ] `closeVouch(uint256 vouchId)` — callable at circle completion:
  - Requires associated circle to be in `COMPLETED` status
  - Settles any remaining interest
  - Releases the locked amount (decreases voucher's `circleObligation` by vouch amount)
  - Sets vouch status to `COMPLETED`
  - Emits `VouchClosed(vouchId)`
- [ ] `expireVouch(uint256 vouchId)` — for grace-period-exhausted exits:
  - Requires vouched member to have exited the circle
  - Settles interest up to exit point
  - Deducts any unsettled interest from vouched member's remaining balance (if any)
  - Releases locked amount
  - Emits `VouchExpired(vouchId)`

### Discovery List
- [ ] `signalVouchingAvailability(uint256 maxAmount, uint256 minCircleTier)`:
  - Adds voucher to the discovery list with their stated parameters
  - Does NOT reveal the voucher's balance — only the amount they're willing to vouch
- [ ] `withdrawVouchingAvailability()`: removes from discovery list
- [ ] `getVouchingOpportunities(uint256 circleId) returns (VouchOpportunity[])`: returns members seeking vouches for a given circle tier, with their ZK history proof included

### Tests
- [ ] Unit tests at `test/unit/SolidarityMarket.test.ts`:
  - `createVouch` → vouch locked, voucher obligation increased
  - `createVouch` exceeding 80% limit → reverts
  - `acceptVouch` by non-vouchedId member → reverts
  - Interest accrual: correct formula
  - `claimInterest` by non-voucher → reverts
  - `onMemberSelected` → correct payout share distributed
  - `closeVouch` before circle completes → reverts
  - `closeVouch` after circle completes → obligation released

- [ ] Integration test at `test/integration/vouch_and_selection.test.ts`:
  - Voucher creates vouch → Vouched member accepts → Joins circle → Selected in round 3 → Verify interest and payout share correctly distributed → Circle completes → Vouch closed → Obligations zeroed

---

## Output Files

- `contracts/core/SolidarityMarket.sol`
- `test/unit/SolidarityMarket.test.ts`
- `test/integration/vouch_and_selection.test.ts`

---

## Notes

- The `onMemberSelected` callback requires a trust boundary: only `SavingsCircle` can call it. Use `onlyCircle` modifier with the immutable `savingsCircle` address.
- `yieldLeveragePremium` must be computed in `SavingsCircle` and passed to the callback — the market contract cannot compute it independently without knowing the member's original balance before the payout.
- In v1, `historyProof` in `acceptVouch` can be a signature from the vouched member attesting to their savings history (cheaper than ZK, lower privacy). ZK proof is the target for v2.
- The 80% diversification floor is checked per-vouch at creation time. If yield fluctuations later push a voucher's total vouched amount above 80% of their balance, the existing vouches are NOT automatically reduced — only new vouches are blocked. Document this clearly.
