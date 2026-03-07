# Task 006-05 — Reallocation Trigger Workflow (US3)

**Spec:** 006 — Automation Layer (Chainlink CRE)
**Milestone:** 3
**Status:** Blocked on Task 006-02
**Estimated effort:** 3–5 days
**Dependencies:** Task 006-02
**Parallel-safe:** Yes (independent of US1, US2)

---

## Objective

Detect members who cannot pay even `minDepositPerRound` for 1 full round; call `initiateReallocation(circleId, memberId)` on SavingsCircle. Per FR-001b: 1 round grace period before reallocation.

---

## Context

Use Case 3 — Spec 006. Per R-003, contract must expose `initiateReallocation` callable by CRE after 1 round of non-payment. See contracts/workflow-contracts.md.

---

## Acceptance Criteria

- [ ] `workflows/reallocation-trigger/index.ts` with cron trigger (round-aligned or every 15 min)
- [ ] `workflows/reallocation-trigger/tasks/index.ts`
- [ ] Read-circles task: enumerate active circles and members per circle
- [ ] Check-payment task: for each member, read `getWithdrawableBalance(shieldedId)` from SavingsAccount, compare to `minDepositPerRound`; detect 1-round non-payment via round boundary + payment status
- [ ] Initiate-reallocation task: when member has failed `minDepositPerRound` for 1+ round, encode and submit `initiateReallocation(circleId, memberId)` on SavingsCircle; wrap with errorHandler (FR-004)
- [ ] Tasks wired: readCircles → checkPayment → initiateReallocation (when applicable)
- [ ] `cre workflow simulate workflows/reallocation-trigger` succeeds

**Note:** `initiateReallocation` may not exist yet in SavingsCircle — workflow implementation blocked until contract exposes it (Spec 002/003).
