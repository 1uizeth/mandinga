# Task 001-01 — Define ISavingsAccount Interface

**Spec:** 001 — Savings Account
**Milestone:** 2
**Status:** Blocked on Milestone 1 (Yield Engine must be deployed to testnet first)
**Estimated effort:** 2 hours
**Dependencies:** Task 004-01 (IYieldRouter)
**Parallel-safe:** Yes (interface definition doesn't require yield engine deployed)

---

## Objective

Define the `ISavingsAccount` Solidity interface. This is the public API surface for the core savings primitive. All other contracts (SavingsCircle, SolidarityMarket) interact with savings accounts only through this interface.

---

## Context

The savings account is the foundational primitive. Its interface must be stable before dependent contracts are designed. The interface must accommodate both the normal operational flow and the emergency exit path.

See: Spec 001 for full user stories and acceptance criteria.

---

## Acceptance Criteria

- [ ] Interface file created at `backend/contracts/interfaces/ISavingsAccount.sol`
- [ ] Interface includes all public-facing functions:
  - `deposit(uint256 amount)` — deposit USDC; starts yielding immediately
  - `withdraw(uint256 amount)` — withdraw up to `balance - circleObligation`
  - `emergencyWithdraw()` — full withdrawal in emergency state (obligation released)
  - `getPosition(bytes32 shieldedId) returns (Position)` — returns full position struct
  - `getWithdrawableBalance(bytes32 shieldedId) returns (uint256)` — `balance - circleObligation`
  - `getCircleObligation(bytes32 shieldedId) returns (uint256)` — current locked amount
  - `setCircleObligation(bytes32 shieldedId, uint256 amount)` — callable only by SavingsCircle contract
  - `activateEmergency()` — callable only by EmergencyModule (timelock-gated)
- [ ] Position struct defined inline:
  ```solidity
  struct Position {
      uint256 balance;
      uint256 circleObligation;
      uint256 yieldEarnedTotal;
      uint256 lastUpdateTimestamp;
      bool emergencyExit;
  }
  ```
- [ ] Events defined:
  - `Deposited(bytes32 indexed shieldedId, uint256 amount)`
  - `Withdrawn(bytes32 indexed shieldedId, uint256 amount)`
  - `YieldCredited(bytes32 indexed shieldedId, uint256 amount)`
  - `ObligationSet(bytes32 indexed shieldedId, uint256 newObligation)`
  - `EmergencyExitExecuted(bytes32 indexed shieldedId, uint256 amountReturned)`
- [ ] Custom errors defined (preferred over `require` strings for gas efficiency):
  - `InsufficientWithdrawableBalance(uint256 requested, uint256 available)`
  - `PrincipalLockViolation(uint256 balance, uint256 obligation)`
  - `NotAuthorized(address caller, address expected)`
  - `EmergencyNotActive()`
- [ ] Interface compiles successfully with `forge build`

---

## Output Files

- `backend/contracts/interfaces/ISavingsAccount.sol`

---

## Notes

- Use `bytes32 shieldedId` rather than `address` throughout state and events. In v1, `shieldedId = keccak256(abi.encodePacked(msg.sender, nonce))` — provides pseudonymity and preserves the v2 privacy migration path without breaking interface changes.
- The `setCircleObligation` function has a strict access control requirement — only the deployed `SavingsCircle` contract address can call it. This address is set at deployment and is immutable.
- `getPosition` may return zeroed struct for unknown shieldedIds — this is correct behaviour (no account = zero balance)
