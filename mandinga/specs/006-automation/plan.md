# Implementation Plan: Spec 006 — Automation Layer (Chainlink CRE)

**Branch**: `006-automation` | **Date**: March 2026 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from Spec 006 — four CRE workflows for protocol automation.

---

## Summary

Implement the Chainlink CRE (Compute Runtime Environment) automation layer for Mandinga Protocol. Four TypeScript workflows run on a DON with cron triggers: (1) automatic circle formation every 1 hour, (2) Safety Net Pool monitor & alert, (3) non-payment reallocation trigger, (4) yield harvest on fixed schedule. **Target network: Base** (Base Sepolia testnet, Base mainnet). Template reference: [cre-templates/bring-your-own-data/workflow-ts](https://github.com/smartcontractkit/cre-templates/tree/main/starter-templates/bring-your-own-data/workflow-ts).

---

## Technical Context

**Language/Version**: TypeScript 5.x (Node 20+ or Bun)  
**Primary Dependencies**: `@chainlink/cre-sdk`, `viem` v2, Bun (package manager)  
**Storage**: N/A — workflows are stateless; state read from chain  
**Testing**: `cre workflow simulate <path>`, unit tests for workflow logic  
**Target Platform**: Chainlink DON (decentralised oracle network); Base chain  
**Project Type**: Off-chain automation workflows (TypeScript)  
**Performance Goals**: Circle formation within 1h of queue readiness; harvest 1x/day  
**Constraints**: CRE DON deployment required; ACE (Access Control Engine) for workflow auth  
**Scale/Scope**: 4 workflows; single-chain (Base) v1

---

## Project Structure

### Documentation (this feature)

```text
mandinga/specs/006-automation/
├── plan.md
├── spec.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── workflow-contracts.md
└── tasks/
    ├── task-01-cre-setup.md
    ├── task-02-foundational.md
    ├── task-03-circle-formation.md
    ├── task-04-safety-pool-monitor.md
    ├── task-05-reallocation-trigger.md
    ├── task-06-yield-harvest.md
    └── task-07-don-deployment.md
```

### CRE Workflows (repository root)

```text
mandinga-protocol/
├── backend/
├── frontend/
└── workflows/
    ├── .cre/
    ├── project.yaml
    ├── secrets.yaml
    ├── package.json
    ├── circle-formation/
    ├── safety-pool-monitor/
    ├── reallocation-trigger/
    ├── yield-harvest/
    └── contracts/abi/
```

---

## Base Network Configuration

- **Testnet**: `ethereum-testnet-sepolia-base-1` (Base Sepolia)
- **Mainnet**: `ethereum-mainnet-base-1` (Base)

---

## Build Order and Milestones

### Milestone 0: CRE Toolchain Setup (Week 1)
- [ ] Install CRE CLI
- [ ] Create `workflows/` with project.yaml (Base RPCs)
- [ ] Bun install: @chainlink/cre-sdk, viem
- [ ] Sync ABIs from backend
- [ ] Validate with `cre workflow simulate`

### Milestone 1: Circle Formation Workflow (Weeks 2–3)
- [ ] Off-chain kickoff algorithm
- [ ] Cron: every 1 hour
- [ ] Call formCircle contract

### Milestone 2: Safety Pool Monitor (Week 4)
- [ ] Read-only; emit alerts
- [ ] No on-chain writes

### Milestone 3: Reallocation Trigger (Week 5)
- [ ] Call initiateReallocation after 1 round grace

### Milestone 4: Yield Harvest (Week 6)
- [ ] Cron: 1x/day
- [ ] Call YieldRouter.harvest()

### Milestone 5: DON Deployment (Weeks 7–8)
- [ ] Deploy to DON on Base
- [ ] Verify cron execution
