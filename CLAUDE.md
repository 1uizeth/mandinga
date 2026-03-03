# mandinga Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-27

## Active Technologies

### Backend (`backend/`)
- Solidity ^0.8.20 + Foundry (forge)
- OpenZeppelin Contracts v5
- OpenZeppelin Foundry Upgrades
- Chainlink VRF v2.5 (selection randomness)
- Aave V3 (sole yield source in v1 — `AaveAdapter.sol`)
- Real-world yield sources (Ondo/Superstate) and `OracleAggregator` deferred to v2

### Frontend (`frontend/`)
- Next.js 14 (App Router)
- TypeScript (strict)
- wagmi v2 + viem v2 (Ethereum interactions)
- shadcn/ui + Tailwind CSS (component primitives)
- @tanstack/react-query (wagmi v2 dependency)
- **Atomic Design** component architecture: `atoms/` → `molecules/` → `organisms/` → `templates/` → `app/` pages

## Project Structure

```text
mandinga-protocol/
├── backend/
│   ├── contracts/        ← Solidity sources (src = "contracts" in foundry.toml)
│   │   ├── core/
│   │   ├── yield/
│   │   ├── governance/
│   │   └── interfaces/
│   ├── script/           ← Forge deploy scripts (*.s.sol)
│   ├── test/             ← Forge tests (*.t.sol)
│   │   ├── unit/
│   │   ├── integration/
│   │   └── invariant/
│   ├── lib/              ← Foundry git submodule dependencies
│   ├── foundry.toml
│   └── Makefile
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
            └── abi/      ← Generated ABIs (synced from backend/out/)
```

## Commands

### Backend
```bash
# from backend/
forge build                    # compile contracts
forge test                     # run all tests
forge test --match-path "test/invariant/*" --invariant-runs 10000
forge script script/DeployYieldEngine.s.sol --broadcast --network arbitrum_sepolia
make sync-abi                  # copy ABIs to frontend/src/lib/abi/
```

### Frontend
```bash
# from frontend/
npm run dev                    # start Next.js dev server
npm run build                  # production build
npm run lint
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

- 004-aave-only-yield: Yield engine scoped to Aave V3 only in v1; OndoAdapter and OracleAggregator deferred to v2
- 003-atomic-design: Frontend components restructured to Atomic Design (atoms → molecules → organisms → templates → pages)
- 002-monorepo-structure: Migrated to `backend/` (Foundry, `contracts/` as src) + `frontend/` (Next.js 14)
- 001-privacy-deferred: Privacy layer deferred to v2; `shieldedId` pseudonymity retained as migration hook
- 001-foundry-fhe-stack: Foundry (forge), OpenZeppelin Contracts v5, OpenZeppelin Foundry Upgrades

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
