# mandinga Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-27

## Active Technologies
- TypeScript 5.x (Node 20+ or Bun) + `@chainlink/cre-sdk`, `viem` v2, Bun (package manager) (006-automation)
- N/A — workflows are stateless; state read from chain (006-automation)
- TypeScript 5.x (Node 20+ or Bun) + Next.js 14 (App Router), wagmi v2, viem v2, Tailwind CSS, shadcn/ui (007-defi-dashboard)
- N/A — state read from chain (007-defi-dashboard)

### Contracts (`contracts/`)
- Solidity ^0.8.20 + Foundry (forge)
- OpenZeppelin Contracts v5
- OpenZeppelin Foundry Upgrades
- Chainlink VRF v2.5 (selection randomness)
- Aave V3 (sole yield source in v1 — `AaveAdapter.sol`)
- Real-world yield sources (Ondo/Superstate) and `OracleAggregator` deferred to v2

### Webapp (`webapp/`) — Spec 007
- Next.js 14 (App Router)
- TypeScript (strict)
- wagmi v2 + viem v2 (Ethereum interactions)
- Tailwind CSS (Light/Dark mode) + shadcn/ui
- Layout reference: [v0-mandingafront.vercel.app](https://v0-mandingafront.vercel.app/)

### Frontend (`frontend/`) — Legacy
- Next.js 14 (App Router)
- TypeScript (strict)
- wagmi v2 + viem v2 (Ethereum interactions)
- shadcn/ui + Tailwind CSS (component primitives)
- @tanstack/react-query (wagmi v2 dependency)
- **Atomic Design** component architecture: `atoms/` → `molecules/` → `organisms/` → `templates/` → `app/` pages

## Project Structure

```text
mandinga-protocol/
├── workflows/            ← Chainlink CRE (Spec 006) — TypeScript, Base
│   ├── circle-formation/   Cron 1h
│   ├── safety-pool-monitor/  Read-only
│   ├── reallocation-trigger/
│   ├── yield-harvest/      Cron 1x/day
│   └── project.yaml        Base RPCs
├── contracts/            ← Foundry project root (run forge from here)
│   ├── foundry.toml      ← src = "src", libs = ["lib"]
│   ├── remappings.txt
│   ├── src/              ← Solidity sources
│   │   ├── core/
│   │   ├── yield/
│   │   ├── governance/   (.gitkeep — v2)
│   │   └── interfaces/
│   ├── script/           ← Forge deploy scripts (*.s.sol)
│   ├── test/             ← Forge tests (*.t.sol)
│   │   ├── unit/
│   │   ├── integration/
│   │   └── invariant/
│   └── lib/              ← Foundry git submodule dependencies
├── webapp/               ← Spec 007 DeFi Dashboard (Next.js, wagmi, Tailwind)
│   └── src/
│       ├── app/
│       ├── components/   (atoms → molecules → organisms → templates)
│       ├── hooks/
│       └── lib/abi/
└── frontend/
    └── src/
        ├── app/          ← Pages (thin: compose Templates + call hooks)
        ├── components/
        │   ├── atoms/    ← Button, Badge, Input, Label, Spinner, Icon
        │   ├── molecules/← TokenAmountDisplay, StatCard, WalletConnectButton
        │   ├── organisms/← SavingsPositionCard, CircleStatusPanel, AppHeader
        │   └── templates/← DashboardTemplate, CircleTemplate, SolidarityTemplate
        ├── hooks/        ← wagmi contract hooks (only used in app/ pages)
        └── lib/
            └── abi/      ← Generated ABIs (synced from contracts/out/)
```

## Commands

### Contracts
```bash
# from contracts/
forge build                    # compile contracts
forge test                     # run all tests
forge test --match-path "test/invariant/*" --invariant-runs 10000
forge script script/DeployYieldEngine.s.sol --broadcast --network base_sepolia
```

### Webapp (Spec 007)
```bash
# from webapp/
pnpm dev                       # start Next.js dev server
pnpm build                     # production build
pnpm lint
```

### Frontend (Legacy)
```bash
# from frontend/
pnpm dev
pnpm build
pnpm lint
```

## Code Style

### Solidity
- Solidity ^0.8.20: Follow standard conventions
- Use custom errors (not `require` strings) for gas efficiency
- `bytes32 shieldedId` instead of `address` in all position state and events
- `ReentrancyGuard` on all fund-moving external functions
- NatSpec on all public/external functions

### TypeScript (Frontend)
- Strict TypeScript
- wagmi v2 `useReadContract` / `useWriteContract` hooks for all contract interactions
- No direct `ethers.js` — use `viem` exclusively
- All USDC amounts as `bigint` (6 decimals)
- **Atomic Design rule:** `useReadContract` / `useWriteContract` only in `hooks/` or `app/` pages — never inside `atoms/`, `molecules/`, `organisms/`, or `templates/`
- Components receive data as typed props; contract state is never fetched inside components

## Key Invariants (must never be violated)

- `sharesBalance >= circleObligationShares` for every SavingsAccount position
- No vouch may exceed 20% of voucher's balance
- Every circle member receives the full pool payout exactly once
- `executeRound()` is permissionless — selection determined by VRF only

## Recent Changes
- 007-defi-dashboard: Added TypeScript 5.x (Node 20+ or Bun) + Next.js 14 (App Router), wagmi v2, viem v2, Tailwind CSS, shadcn/ui
- 006-automation: Added TypeScript 5.x (Node 20+ or Bun) + `@chainlink/cre-sdk`, `viem` v2, Bun (package manager)

- 004-aave-only-yield: Yield engine scoped to Aave V3 only in v1; OndoAdapter and OracleAggregator deferred to v2

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
