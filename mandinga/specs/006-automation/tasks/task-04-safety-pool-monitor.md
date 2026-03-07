# Task 006-04 — Safety Pool Monitor Workflow (US2)

**Spec:** 006 — Automation Layer (Chainlink CRE)
**Milestone:** 2
**Status:** Blocked on Task 006-02
**Estimated effort:** 3–5 days
**Dependencies:** Task 006-02
**Parallel-safe:** Yes (independent of US1)

---

## Objective

Read-only workflow: detect members needing Safety Net Pool coverage, emit alert. CRE does NOT call the pool — member calls.

---

## Context

Use Case 2 — Spec 006. Per FR-001a, member calls the pool; CRE only monitors and alerts.

---

## Acceptance Criteria

- [ ] `workflows/safety-pool-monitor/index.ts` with cron trigger (round-aligned or every N min)
- [ ] `workflows/safety-pool-monitor/tasks/index.ts`
- [ ] Read-circles task: call `getActiveCircles()`, `getMembersWithMinOption(circleId)` on SavingsCircle
- [ ] Check-balance task: for each member with min option, read `getWithdrawableBalance(shieldedId)` from SavingsAccount, compare to `minDepositPerRound` (coverage needed when balance below min)
- [ ] Emit-alert task: when `accountBalance < depositPerRound`, emit alert (console.log or event for indexer)
- [ ] Tasks wired: readCircles → checkBalance → emitAlert
- [ ] `cre workflow simulate workflows/safety-pool-monitor` succeeds
