# Task 001-02 — Implement SavingsAccount Contract

**Spec:** 001 — Savings Account
**Milestone:** 2
**Status:** Blocked on Task 001-01
**Estimated effort:** 12 hours
**Dependencies:** Task 001-01 (ISavingsAccount), Task 004-01/02/03 (Yield Engine complete)
**Parallel-safe:** No — sequential after 001-01

---

## Objective

Implement `SavingsAccount.sol` — the core savings primitive. This contract holds member positions, enforces the principal lock invariant, integrates with the yield router for automatic yield accrual, and exposes the emergency exit path.

---

## Context

This is the most critical contract in the protocol. Its principal lock invariant (`balance >= circleObligation`) is the structural enforcement that eliminates default risk from savings circles. It must be bulletproof.

See: Spec 001 all user stories, plan.md §3.1.

---

## Acceptance Criteria

### Contract Implementation
- [ ] Contract at `contracts/core/SavingsAccount.sol` implementing `ISavingsAccount`
- [ ] Constructor takes: `IYieldRouter yieldRouter`, `address emergencyModule`, `address savingsCircle`, `address stablecoin`
- [ ] `deposit(uint256 amount)`:
  - Transfers USDC from caller to contract
  - Computes `shieldedId` from caller's address + a commitment nonce (enables privacy migration later)
  - Updates `positions[shieldedId].balance`
  - Calls `yieldRouter.allocate(amount)`
  - Emits `Deposited`
  - Reverts with `ZeroAmount` if amount == 0
- [ ] `withdraw(uint256 amount)`:
  - Checks `positions[shieldedId].balance - positions[shieldedId].circleObligation >= amount`
  - Calls `yieldRouter.withdraw(amount)` to retrieve USDC
  - Updates balance
  - Transfers USDC to caller
  - Emits `Withdrawn`
  - Reverts with `InsufficientWithdrawableBalance` if check fails
- [ ] `creditYield(bytes32 shieldedId, uint256 amount)` — callable only by YieldRouter:
  - Adds yield to `positions[shieldedId].balance`
  - Updates `yieldEarnedTotal`
  - Emits `YieldCredited`
- [ ] `setCircleObligation(bytes32 shieldedId, uint256 amount)` — callable only by SavingsCircle:
  - Sets `circleObligation`
  - Validates `balance >= amount` (reverts with `PrincipalLockViolation` if not)
  - Emits `ObligationSet`
- [ ] `emergencyWithdraw()` — only callable when `emergencyActive == true`:
  - Releases the obligation: sets `circleObligation = 0`
  - Withdraws full balance
  - Marks position as exited
  - Emits `EmergencyExitExecuted`
- [ ] `activateEmergency()` — only callable by `emergencyModule` address:
  - Sets `emergencyActive = true` globally
  - Emits `EmergencyActivated`
- [ ] ReentrancyGuard on all external functions that move funds
- [ ] Immutable addresses for `savingsCircle` and `emergencyModule` set at construction

### Invariant
- [ ] Add invariant check `assert(positions[id].balance >= positions[id].circleObligation)` as an internal guard on every state-modifying function (can be removed in production build after formal verification, but required for testnet)

### Tests
- [ ] Unit tests at `test/unit/SavingsAccount.test.ts`:
  - Deposit → balance reflects deposit
  - Withdraw free balance → succeeds
  - Withdraw locked balance → reverts with `InsufficientWithdrawableBalance`
  - `setCircleObligation` exceeding balance → reverts with `PrincipalLockViolation`
  - `setCircleObligation` by non-SavingsCircle → reverts with `NotAuthorized`
  - Emergency: `activateEmergency` → `emergencyWithdraw` returns full balance including locked
  - Emergency: `activateEmergency` by non-module → reverts
  - Yield crediting: `creditYield` increases balance and `yieldEarnedTotal`
  - Reentrancy: attempt reentrant withdrawal → reverts

- [ ] Fuzz test at `test/invariant/balance_invariants.test.ts`:
  - Random sequence of deposits, withdrawals, obligation sets, and yield credits
  - After each operation: assert `balance >= circleObligation` for all positions

---

## Output Files

- `contracts/core/SavingsAccount.sol`
- `test/unit/SavingsAccount.test.ts`
- `test/invariant/balance_invariants.test.ts`

---

## Notes

- The `shieldedId` computed from `msg.sender` in v1 is a simplification. In the privacy layer migration (future work), `shieldedId` will be a ZK commitment that does not reveal the member's address. Design the contract to make this swap easy: use `bytes32 shieldedId` consistently throughout, never `address`.
- Do not store the raw `msg.sender` address anywhere in the position state — only the derived `shieldedId`. This preserves the migration path to full privacy.
- The `yieldRouter.withdraw()` call in the withdraw flow must come AFTER the balance check and BEFORE the USDC transfer (checks-effects-interactions).
