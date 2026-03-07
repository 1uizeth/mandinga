# Task 006-03 — Circle Formation Workflow (US1)

**Spec:** 006 — Automation Layer (Chainlink CRE)
**Milestone:** 1
**Status:** Blocked on Task 006-02
**Estimated effort:** 1–2 weeks
**Dependencies:** Task 006-02
**Parallel-safe:** Partial

---

## Objective

Implement the circle formation workflow: cron every 1h, read queue, run kickoff off-chain, call formCircle. MVP workflow.

---

## Context

Use Case 1 — Spec 006. Contract interface per contracts/workflow-contracts.md and Spec 002 US-006. Kickoff algorithm runs off-chain.

**SavingsCircle model:** `createCircle` creates a circle in FORMING state; members join via `joinCircle(circleId)` (per-member, msg.sender). The workflow calls `createCircle` only; members join separately (frontend or other flows).

---

## Acceptance Criteria

- [ ] `workflows/circle-formation/index.ts` with cron trigger `0 * * * *` and stub task
- [ ] `workflows/circle-formation/tasks/index.ts` exporting task functions
- [ ] Kickoff algorithm in `workflows/circle-formation/tasks/kickoff.ts`: queue grouping by `(depositPerRound, duration)`, N selection, formation threshold (70%), APY from YieldRouter
- [ ] Read-queue task in `workflows/circle-formation/tasks/readQueue.ts`: call `getQueuedIntents(depositPerRound, duration)` on Queue contract
- [ ] Form-circle task in `workflows/circle-formation/tasks/formCircle.ts`: encode and submit `SavingsCircle.createCircle(poolSize, memberCount, roundDuration, minDepositPerRound)` using ABI from `workflows/contracts/abi/SavingsCircle.json`; derive params from kickoff (`poolSize = N × depositPerRound`, `roundDuration = duration / N`, `minDepositPerRound = 0`); wrap with errorHandler for retry/backoff/alert (FR-004)
- [ ] Tasks wired in index.ts: readQueue → kickoff → formCircle (when viable)
- [ ] Unit tests for kickoff logic in `workflows/circle-formation/tasks/kickoff.test.ts`
- [ ] `cre workflow simulate workflows/circle-formation` succeeds
