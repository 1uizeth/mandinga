# Spec 007 — DeFi Dashboard Quickstart

**Target**: Base Sepolia (testnet), Base mainnet  
**App**: `webapp/` at repo root

---

## Prerequisites

1. **Node.js 20+** or **Bun** — [Install](https://nodejs.org) / [Bun](https://bun.sh)
2. **Deployed contracts** on Base Sepolia (SavingsAccount, SavingsCircle, YieldRouter, MockUSDC)
3. **Wallet** — MetaMask or WalletConnect-compatible wallet

---

## Setup

```bash
# From repo root
cd webapp
pnpm install   # or: bun install

# Copy env template
cp .env.example .env.local
# Edit .env.local: NEXT_PUBLIC_CHAIN_ID, contract addresses, etc.
```

---

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NEXT_PUBLIC_CHAIN_ID` | Target chain ID | `84532` (Base Sepolia) |
| `NEXT_PUBLIC_RPC_URL` | RPC endpoint | `https://base-sepolia-rpc.publicnode.com` |
| `NEXT_PUBLIC_SAVINGS_ACCOUNT` | SavingsAccount address | `0x...` |
| `NEXT_PUBLIC_SAVINGS_CIRCLE` | SavingsCircle address | `0x...` |
| `NEXT_PUBLIC_YIELD_ROUTER` | YieldRouter address | `0x...` |
| `NEXT_PUBLIC_USDC` | USDC/MockUSDC address | `0x...` |
| `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` | WalletConnect project ID | From cloud.walletconnect.com |

---

## Run Development Server

```bash
# From webapp/
pnpm dev
# Open http://localhost:3000
```

---

## Build & Lint

```bash
pnpm build                     # Production build
pnpm lint                      # ESLint
```

---

## Contract ABIs

ABIs are synced from `contracts/out/`:

```bash
# From repo root (after forge build)
cp contracts/out/SavingsAccount.sol/SavingsAccount.json webapp/src/lib/abi/
cp contracts/out/SavingsCircle.sol/SavingsCircle.json webapp/src/lib/abi/
cp contracts/out/IYieldRouter.sol/IYieldRouter.json webapp/src/lib/abi/
# ... etc.
```

---

## Key Flows

1. **Connect** → Click wallet button → Select provider → Approve
2. **Deposit** → Savings Account view → Enter amount → Approve USDC → Confirm deposit
3. **View Circles** → Navigate to Circles → See list with status and next round date
4. **Yield** → Dashboard shows cumulative yield at a glance
