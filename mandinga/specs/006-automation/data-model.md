# Spec 006 — Automation Layer: Data Model

**Date**: March 2026  
**Scope**: Workflow entities and on-chain state read by CRE

---

## Workflow Entities (Off-Chain)

CRE workflows are **stateless**. No persistent off-chain storage. Each run:
1. Reads on-chain state via RPC
2. Optionally computes (kickoff algorithm)
3. Optionally submits transaction

### Workflow Run

| Field | Type | Description |
|-------|------|-------------|
| workflowId | string | e.g. `circle-formation`, `yield-harvest` |
| chainName | string | `ethereum-testnet-sepolia-base-1` or `ethereum-mainnet-base-1` |
| cronExpression | string | `0 * * * *` (1h), `0 0 * * *` (1d) |
| lastRunBlock | number | For idempotency / skip logic |

---

## On-Chain State Read by Workflows

### Circle Formation Workflow

| Source | Data |
|--------|------|
| Queue contract | Queued intents grouped by `(depositPerRound, duration)` |
| YieldRouter | Current APY for kickoff viability |
| Formation threshold | Governance config (default 70%) |

### Safety Pool Monitor Workflow

| Source | Data |
|--------|------|
| SavingsCircle | Active circles, members with minimum option |
| SavingsAccount | `accountBalance` per member |
| Round boundary | `depositPerRound` vs balance |

### Reallocation Trigger Workflow

| Source | Data |
|--------|------|
| SavingsCircle | Members, round index, payment status |
| SavingsAccount | Balance vs `minDepositPerRound` |
| Grace period | 1 round — contract enforces |

### Yield Harvest Workflow

| Source | Data |
|--------|------|
| YieldRouter | `harvest()` callable |
| (Optional) Aave | APY for monitoring |

---

## Contract Interfaces (Workflow → Chain)

| Contract | Method | Workflow | Notes |
|----------|--------|----------|-------|
| Formation / CircleFactory | `formCircle(queueGroupId, selectedN, memberIds)` | circle-formation | See contracts/workflow-contracts.md |
| SavingsCircle | `initiateReallocation(circleId, memberId)` | reallocation-trigger | R-003 |
| YieldRouter | `harvest()` | yield-harvest | Permissionless or DON-only |
| SafetyNetPool | — | safety-pool-monitor | **Read-only**; member calls |
