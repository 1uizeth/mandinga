# Task 006-02 — Foundational (ABI Sync & Shared Config)

**Spec:** 006 — Automation Layer (Chainlink CRE)
**Milestone:** 0
**Status:** Blocked on Task 006-01
**Estimated effort:** 2–3 hours
**Dependencies:** Task 006-01
**Parallel-safe:** Partial (T009, T010 can run in parallel)

---

## Objective

Shared infrastructure for all workflows: ABI sync, chain config helper, error handler (FR-004), env template.

---

## Context

All workflows need ABIs from backend and a shared error handler for retry/backoff/alert on contract failures. See contracts/workflow-contracts.md for required ABIs.

---

## Acceptance Criteria

- [ ] Makefile target or script to sync ABIs from `backend/out/` to `workflows/contracts/abi/` (YieldRouter, SavingsCircle, SavingsAccount, SafetyNetPool)
- [ ] `workflows/contracts/abi/.gitkeep` if ABIs not yet available; document required ABIs in `workflows/README.md`
- [ ] `workflows/lib/getBaseRpcUrl(chainName)` for `ethereum-testnet-sepolia-base-1` and `ethereum-mainnet-base-1`
- [ ] `workflows/.env.example` with `CRE_ETH_PRIVATE_KEY` and RPC override vars
- [ ] `workflows/lib/errorHandler.ts` with retry (exponential backoff), alertOnFailure for contract call failures — satisfies FR-004
