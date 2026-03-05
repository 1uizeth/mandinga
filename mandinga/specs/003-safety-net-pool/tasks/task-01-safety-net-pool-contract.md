# Task 003-01 — Implement SafetyNetPool Contract

**Spec:** 003 — Safety Net Pool (v1.0 / v1.1)
**Milestone:** 4
**Status:** Done ✓
**Estimated effort:** 14 hours (actual ~8h)
**Dependencies:** Task 002-01 (SavingsCircle), Task 001-02 (SavingsAccount)
**Parallel-safe:** No

---

## Objective

Implement `SafetyNetPool.sol` — the pool that enables minimum-installment coverage for
SavingsCircle members. Depositors lock USDC to earn yield; the pool covers paused member
slots when `SavingsCircle.checkAndPause` is called.

---

## Spec alignment

This task was regenerated from **Spec 003 v1.0/v1.1** (installment coverage model).
The previous task file described the archived bilateral-vouching model (v0.4) and has been
replaced by this file.

---

## Acceptance Criteria

### Contract Structure
- [x] Contract at `contracts/src/core/SafetyNetPool.sol`
- [x] Constructor takes: `ISavingsAccount`, `IYieldRouter`, `IERC20 usdc`, `address circle`, `address governance`, `uint256 initialRateBps`
- [x] Implements `ICircleBuffer` — SavingsCircle calls `coverSlot` / `releaseSlot`

### Pool Deposits (US-001)
- [x] `deposit(uint256 amount, uint256 lockDuration)` — pulls USDC, routes to YieldRouter, mints pool shares
- [x] First depositor: 1 pool share per USDC; subsequent: pro-rata on pre-deposit pool value
- [x] `lockDuration` recorded on position (informational in v1; lock is not enforced for undeployed capital per AC-002-1)
- [x] Emits `Deposited(shieldedId, amount, lockDuration, newPoolShares)`

### Pool Withdrawals (US-002)
- [x] `withdraw(uint256 amount)` — burns pool shares, redeems from YieldRouter
- [x] Only pro-rata undeployed (available) capital is withdrawable
- [x] Reverts `InsufficientWithdrawable` if `amount > getWithdrawable(shieldedId)`
- [x] Reverts `NoPosition` if caller has no pool shares
- [x] Emits `Withdrawn(shieldedId, amount, burntPoolShares)`

### ICircleBuffer — Slot Coverage (US-003 / US-005)
- [x] `coverSlot(uint256 circleId, uint16 slot, uint256 amount)` — only callable by `circle`; checks available capital; marks `totalDeployed`
- [x] `releaseSlot(uint256 circleId, uint16 slot)` — only callable by `circle`; restores available capital
- [x] Reverts `InsufficientAvailableCapital` if pool lacks sufficient undeployed capital
- [x] Reverts `OnlyCircle` if caller is not the authorised SavingsCircle
- [x] Reverts `SlotNotCovered` on `releaseSlot` for unknown coverage

### View helpers
- [x] `getTotalCapital()` — pool value including accrued yield
- [x] `getAvailableCapital()` — undeployed portion
- [x] `getWithdrawable(bytes32 shieldedId)` — pro-rata withdrawable for a depositor
- [x] `getPositionValue(bytes32 shieldedId)` — full position value including yield
- [x] `slotCoverages(circleId, slot)` — public mapping for coverage state

### Governance
- [x] `coverageRateBps` — configurable annual coverage rate (OQ-005 placeholder)
- [x] `setCoverageRate(uint256 newRateBps)` — only governance; emits `CoverageRateUpdated`
- [x] `COVERAGE_WINDOW_ROUNDS = 3` constant (OQ-002 default)

### Tests
- [x] Unit tests at `test/unit/SafetyNetPool.t.sol` (34 tests, all passing):
  - Constructor verification
  - Deposit: events, YieldRouter routing, share minting, multiple deposits, zero-amount revert
  - Withdraw: USDC transfer, share burning, events, partial, reverts
  - `coverSlot`: records coverage, deploys capital, OnlyCircle check, insufficient-capital revert
  - `releaseSlot`: restores capital, events, not-covered revert, OnlyCircle check
  - Multiple slots: accumulated `totalDeployed`, sequential release
  - Governance: `setCoverageRate` success & unauthorised revert
  - `getPositionValue`: single and two-depositor pro-rata

- [x] Integration tests at `test/integration/PoolCoverageIntegration.t.sol` (5 tests, all passing):
  - Pool deposit → `checkAndPause` (pool covers slot) → member tops up → `resumePausedMember` (pool releases)
  - Pool empty → `checkAndPause` reverts `InsufficientAvailableCapital`
  - Multiple paused slots, sequential release
  - Pool depositor withdraws undeployed capital while one slot is covered
  - Full 3-round circle lifecycle with one pause/resume cycle; pool capital intact at completion

---

## Output Files

- `contracts/src/core/SafetyNetPool.sol`
- `contracts/test/unit/SafetyNetPool.t.sol`
- `contracts/test/integration/PoolCoverageIntegration.t.sol`

---

## Implementation Notes

### v1 design decisions

| Open Question | Decision |
|---|---|
| OQ-001 (min pool depth) | No minimum enforced in v1; `coverSlot` reverts if available < required |
| OQ-002 (coverage window) | `COVERAGE_WINDOW_ROUNDS = 3` constant; not yet enforced in contract logic |
| OQ-003 (lock matching) | Fungible pool — no per-depositor deployment attribution |
| OQ-004 (privacy / ZK debt) | Deferred to v2 (positions are shielded; ZK proof of debt-in-range not required in v1) |
| OQ-005 (coverage rate) | Fixed governance-set rate; `coverageRateBps` is stored state, default 5% APY |

### Deferred to v2
- `safetyNetDebtShares` per member position and minimum-installment gap mechanics (US-003 / US-004)
- Atomic debt settlement at selection (US-004)
- Enforcement of `COVERAGE_WINDOW_ROUNDS` before circle shrinks to N-1 (US-005)
- Lock-duration enforcement for depositors (currently informational only)
- Coverage interest accrual from `coverageRateBps` (rate is stored but not charged in v1)

### Pool share model
Pool shares are minted proportionally to contribution against pool value *before* the deposit.
This is the standard ERC4626 vault entry-price pattern.

`sharesToMint = amount * totalPoolShares / prevPoolValue` (1:1 for first depositor)

Withdrawable for a depositor: `available * depositorShares / totalPoolShares`
where `available = convertToAssets(totalYRShares) − totalDeployed`.
