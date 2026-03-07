# Task 006-06 — Yield Harvest Workflow (US4)

**Spec:** 006 — Automation Layer (Chainlink CRE)
**Milestone:** 4
**Status:** Blocked on Task 006-02
**Estimated effort:** 2–3 days
**Dependencies:** Task 006-02
**Parallel-safe:** Yes (independent of US1–US3)

---

## Objective

Workflow runs every 5 minutes; calls `YieldRouter.harvest()` on Base. Aligned with `HARVEST_COOLDOWN = 5 minutes` in YieldRouter.

---

## Context

Use Case 4 — Spec 006. Cron: `*/5 * * * *` (every 5 min). APY check optional for monitoring.

---

## Acceptance Criteria

- [ ] `workflows/yield-harvest/index.ts` with cron trigger `*/5 * * * *`
- [ ] `workflows/yield-harvest/tasks/index.ts`
- [ ] Harvest task in `workflows/yield-harvest/tasks/harvest.ts`: encode and submit `harvest()` on YieldRouter; wrap with errorHandler for retry/backoff/alert (FR-004)
- [ ] Task wired in index.ts
- [ ] (Optional) APY-monitor task: read `getBlendedAPY()` for logging/alerting
- [ ] `cre workflow simulate workflows/yield-harvest` succeeds
