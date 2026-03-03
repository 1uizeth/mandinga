# Task 006-05 — Reallocation Trigger Workflow (US3)

**Spec:** 006 — Automation Layer (Chainlink CRE)
**Milestone:** 3
**Status:** Blocked on Task 006-02
**Estimated effort:** 3–5 days
**Dependencies:** Task 006-02
**Parallel-safe:** Yes (independent of US1, US2)

---

## Objective

Detect members with `balance < minDepositPerRound` for 1+ round; call `initiateReallocation(circleId, memberId)` on SavingsCircle.

---

## Context

Use Case 3 — Spec 006. Grace period: 1 round (FR-001b). Contract must expose `initiateReallocation` per R-003.

---

## Acceptance Criteria

- [ ] `workflows/reallocation-trigger/index.ts` with cron trigger (round-aligned)
- [ ] `workflows/reallocation-trigger/tasks/index.ts`
- [ ] Scan-circles task: read `getCircles()`, `getMemberPaymentStatus(circleId, memberId, round)` from SavingsCircle
- [ ] Check-grace task: verify 1-round grace (balance < minDepositPerRound for 1+ round)
- [ ] Initiate-reallocation task: encode and submit `initiateReallocation(circleId, memberId)`; wrap with errorHandler for retry/backoff/alert (FR-004)
- [ ] Tasks wired: scanCircles → checkGrace → initiateReallocation
- [ ] `cre workflow simulate workflows/reallocation-trigger` succeeds
