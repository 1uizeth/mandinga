# Task 006-01 — CRE Toolchain Setup

**Spec:** 006 — Automation Layer (Chainlink CRE)
**Milestone:** 0
**Status:** Ready
**Estimated effort:** 2–3 hours
**Dependencies:** None
**Parallel-safe:** Partial (T003–T005 can run in parallel)

---

## Objective

Initialize the CRE workflow environment: install CLI, create directory structure, configure Base RPCs, add dependencies.

---

## Context

See Spec 006 and plan.md. Target network: Base (ethereum-testnet-sepolia-base-1, ethereum-mainnet-base-1). Template: [cre-templates/bring-your-own-data/workflow-ts](https://github.com/smartcontractkit/cre-templates/tree/main/starter-templates/bring-your-own-data/workflow-ts).

---

## Acceptance Criteria

- [x] CRE CLI installed per https://docs.chain.link/cre; `cre version` succeeds
- [x] `workflows/` directory created at repo root with: `circle-formation/`, `safety-pool-monitor/`, `reallocation-trigger/`, `yield-harvest/`, `contracts/abi/`
- [x] `workflows/project.yaml` added with Base RPCs: `ethereum-testnet-sepolia-base-1`, `ethereum-mainnet-base-1` (urls per plan.md)
- [x] `workflows/secrets.yaml` template with `CRE_ETH_PRIVATE_KEY` placeholder
- [x] `workflows/.cre/` config directory created
- [x] `workflows/package.json` created with Bun; dependencies: `viem` v2 (cre-sdk optional for DON deployment)
- [x] `bun install` in `workflows/` completes without errors
