# Task 006-07 — DON Deployment & Polish

**Spec:** 006 — Automation Layer (Chainlink CRE)
**Milestone:** 5
**Status:** Blocked on Tasks 006-03 through 006-06
**Estimated effort:** 1–2 weeks
**Dependencies:** All workflow tasks complete
**Parallel-safe:** Partial

---

## Objective

Deploy workflows to DON on Base Sepolia, verify cron execution, document gas and LINK cost.

---

## Context

FR-000: v1 MUST include CRE DON deployment and ACE configuration. See plan.md Milestone 5.

---

## Acceptance Criteria

- [ ] DON family and ACE configured for workflow auth (Base Sepolia)
- [ ] Circle-formation workflow deployed to DON
- [ ] Safety-pool-monitor workflow deployed to DON
- [ ] Reallocation-trigger workflow deployed to DON
- [ ] Yield-harvest workflow deployed to DON
- [ ] Cron execution verified for each workflow; on-chain transactions succeed
- [ ] Gas budget and LINK cost per run documented in research.md (NFR-001, NFR-002)
- [ ] `workflows/README.md` with quickstart per quickstart.md
- [ ] Full `cre workflow simulate` for all four workflows; quickstart updated if needed
