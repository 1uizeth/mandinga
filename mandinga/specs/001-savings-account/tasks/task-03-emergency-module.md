# Task 001-03 — Implement EmergencyModule

**Spec:** 001 — Savings Account (US-005: Emergency Exit)
**Milestone:** 2
**Status:** Ready to implement alongside SavingsAccount
**Estimated effort:** 4 hours
**Dependencies:** Task 001-01 (ISavingsAccount interface)
**Parallel-safe:** Yes (can be built concurrently with SavingsAccount)

---

## Objective

Implement `EmergencyModule.sol` — a time-locked governance-controlled module that can declare a protocol emergency state, enabling all members to withdraw their full balance (including any locked circle obligations) without restriction.

---

## Context

Self-custody is a constitutional principle. The emergency exit proves that self-custody is real: if the protocol is exploited, if the team disappears, or if an irrecoverable bug is found, members must always be able to get their money out. This module is the last line of defence.

See: Spec 001, US-005 (Emergency Exit).

---

## Acceptance Criteria

- [ ] Contract at `contracts/core/EmergencyModule.sol`
- [ ] Constructor takes: `ISavingsAccount savingsAccount`, `address governance` (multi-sig or governor), `uint256 timelockDuration` (minimum: 7 days)
- [ ] `proposeEmergency(string calldata reason)` — callable only by `governance`:
  - Records the proposal timestamp
  - Emits `EmergencyProposed(reason, executeAfter)` where `executeAfter = block.timestamp + timelockDuration`
  - Starts the public timelock window
- [ ] `executeEmergency()` — callable by anyone after timelock expires:
  - Requires `block.timestamp >= executeAfter`
  - Calls `savingsAccount.activateEmergency()`
  - Emits `EmergencyActivated(block.timestamp)`
  - Marks module as used (prevents re-activation)
- [ ] `cancelEmergency()` — callable only by `governance` during the timelock window:
  - Cancels a pending emergency proposal
  - Emits `EmergencyCancelled`
  - Resets the proposal state
- [ ] `getEmergencyStatus() returns (bool proposed, uint256 executeAfter, bool activated)`:
  - Public view function so anyone can check the state
- [ ] Unit tests at `test/unit/EmergencyModule.test.ts`:
  - Non-governance proposes emergency → reverts
  - Governance proposes → timelock starts
  - Execute before timelock → reverts
  - Execute after timelock → `savingsAccount.activateEmergency()` called
  - Execute twice → reverts (already activated)
  - Cancel during timelock → proposal cleared
  - Cancel after activation → reverts (too late)
  - `getEmergencyStatus` returns correct state at each stage

---

## Output Files

- `contracts/core/EmergencyModule.sol`
- `test/unit/EmergencyModule.test.ts`

---

## Notes

- The 7-day timelock window is the critical user protection: it gives members time to observe the proposal and decide whether to exit proactively before the emergency state is declared
- The `reason` parameter in `proposeEmergency` is important: it is the public justification for the emergency. It should be emitted and stored (off-chain via event) so the community can evaluate it during the timelock
- `governance` in v1 is a 3-of-5 multi-sig. In a later version it will be the on-chain governor. The interface does not change between these implementations.
- Do not use `tx.origin` anywhere — only `msg.sender`
