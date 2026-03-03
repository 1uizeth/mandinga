# Spec 006 — Automation Layer: Research

**Date**: March 2026  
**Status**: Consolidated from spec clarifications and template analysis

---

## Decision 1: CRE Template — bring-your-own-data/workflow-ts

**Decision:** Use [cre-templates/bring-your-own-data/workflow-ts](https://github.com/smartcontractkit/cre-templates/tree/main/starter-templates/bring-your-own-data/workflow-ts) as the structural reference for Mandinga workflows.

**Rationale:** TypeScript workflow structure with `project.yaml`, `secrets.yaml`, `.cre/`; RPC configuration for multiple chains (including Base); `cre workflow simulate` for local testing; Bun as package manager.

---

## Decision 2: Target Network — Base

**Decision:** Focus CRE workflows on **Base** (ethereum-testnet-sepolia-base-1 for testnet, ethereum-mainnet-base-1 for mainnet).

**Rationale:** User request; lower gas; Chainlink CRE supports Base; Base Sepolia RPC available.

---

## Decision 3: Workflow Layout — One Directory per Use Case

**Decision:** Four separate workflow directories: `circle-formation/`, `safety-pool-monitor/`, `reallocation-trigger/`, `yield-harvest/`.

**Rationale:** Different cron schedules (1h vs 1d vs round-aligned); independent deployment and configuration.

---

## Decision 4: Kickoff Algorithm — Off-Chain

**Decision:** Kickoff algorithm (Spec 002 US-006) runs **off-chain** in the CRE workflow. Workflow computes optimal N, member list, then calls `formCircle(queueGroupId, selectedN, memberIds)`.

**Rationale:** On-chain computation would be gas-intensive. CRE reads state, computes, submits minimal calldata.

---

## Decision 5: Safety Pool — Monitor Only

**Decision:** CRE workflow for Safety Pool **does not call** the pool contract. Member calls. CRE monitors and alerts.

**Rationale:** Per Spec 006 clarifications (Session 2026-03-03).
