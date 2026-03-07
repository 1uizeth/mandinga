# Spec 006 — CRE Workflows Quickstart

**Target**: Base (Base Sepolia testnet, Base mainnet)  
**Template**: [cre-templates/bring-your-own-data/workflow-ts](https://github.com/smartcontractkit/cre-templates/tree/main/starter-templates/bring-your-own-data/workflow-ts)

---

## Prerequisites

1. **CRE CLI** — [Install](https://docs.chain.link/cre)
2. **Bun** — [Install](https://bun.sh)
3. **Backend contracts** deployed on Base Sepolia (for integration tests)

---

## Setup

```bash
# From repo root
cd workflows
bun install

# Add private key to .env (for chain writes)
echo "CRE_ETH_PRIVATE_KEY=your_key_here" > .env
```

---

## Configure RPCs

Edit `workflows/project.yaml`:

```yaml
rpcs:
  - chain-name: ethereum-testnet-sepolia-base-1
    url: https://base-sepolia-rpc.publicnode.com
  - chain-name: ethereum-mainnet-base-1
    url: https://mainnet.base.org
```

---

## Simulate Workflows

```bash
# From repo root
cre workflow simulate workflows/circle-formation
cre workflow simulate workflows/safety-pool-monitor
cre workflow simulate workflows/reallocation-trigger
cre workflow simulate workflows/yield-harvest
```

---

## Workflow Schedules

| Workflow | Cron | Chain |
|----------|------|-------|
| circle-formation | `0 * * * *` (every 1h) | Base |
| safety-pool-monitor | Round-aligned or every N min | Base |
| reallocation-trigger | Round-aligned | Base |
| yield-harvest | `*/5 * * * *` (every 5 min) | Base |

---

## Next Steps

1. Implement each workflow per plan.md milestones
2. Deploy DON and ACE for Base
3. Register workflows with cron triggers
4. Monitor gas and LINK cost per run
