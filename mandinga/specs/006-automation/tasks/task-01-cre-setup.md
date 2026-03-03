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

- [ ] CRE CLI installed per https://docs.chain.link/cre; `cre --version` succeeds
- [ ] `workflows/` directory created at repo root with: `circle-formation/`, `safety-pool-monitor/`, `reallocation-trigger/`, `yield-harvest/`, `contracts/abi/`
- [ ] `workflows/project.yaml` added with Base RPCs: `ethereum-testnet-sepolia-base-1`, `ethereum-mainnet-base-1` (urls per plan.md)
- [ ] `workflows/secrets.yaml` template with `CRE_ETH_PRIVATE_KEY` placeholder
- [ ] `workflows/.cre/` config directory created
- [ ] `workflows/package.json` created with Bun; dependencies: `@chainlink/cre-sdk`, `viem` v2
- [ ] `bun install` in `workflows/` completes without errors
