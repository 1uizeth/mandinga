# Implementation Plan: DeFi Dashboard

**Branch**: `007-defi-dashboard` | **Date**: 2026-03-06 | **Spec**: [spec.md](./spec.md)  
**Input**: Build a frontend web application to interact with Mandinga smart contracts. User request: webapp folder in root, NextJS, TypeScript, Viem/Wagmi, Tailwind (Light/Dark mode), layout based on [v0-mandingafront.vercel.app](https://v0-mandingafront.vercel.app/).

## Summary

DeFi Dashboard is a frontend web app enabling users to connect wallets, activate Savings Accounts, view Savings Circles participation, and see cumulative yield. The app reads from deployed contracts (SavingsAccount, SavingsCircle, YieldRouter) and uses MockUSDC on testnet displayed as USDC. Layout follows the v0 Mandinga reference: header, browse circles, card-based UI with status badges and filters.

## Technical Context

**Language/Version**: TypeScript 5.x (Node 20+ or Bun)  
**Primary Dependencies**: Next.js 14 (App Router), wagmi v2, viem v2, Tailwind CSS, shadcn/ui  
**Storage**: N/A — state read from chain  
**Testing**: Vitest, Playwright (or Jest + React Testing Library)  
**Target Platform**: Web (modern browsers)  
**Project Type**: web-application (single frontend)  
**Performance Goals**: Balance/shares visible within 2s; connect within 30s  
**Constraints**: Atomic Design (atoms → molecules → organisms → templates → pages); contract hooks only in hooks/ or app/  
**Scale/Scope**: Single webapp; wallet connection, savings account, circles view, yield overview

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The constitution template (`.specify/memory/constitution.md`) contains placeholders only. No project-specific constitution gates are defined. Proceeding with plan execution.

## Project Structure

### Documentation (this feature)

```text
mandinga/specs/007-defi-dashboard/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (UI/API contracts)
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
webapp/
├── src/
│   ├── app/             # Next.js App Router pages (thin: compose templates + hooks)
│   ├── components/
│   │   ├── atoms/       # Button, Badge, Input, Label, Spinner, Icon
│   │   ├── molecules/  # TokenAmountDisplay, StatCard, WalletConnectButton
│   │   ├── organisms/   # SavingsPositionCard, CircleStatusPanel, AppHeader
│   │   └── templates/   # DashboardTemplate, CircleTemplate
│   ├── hooks/           # wagmi contract hooks (useReadContract, useWriteContract)
│   └── lib/
│       └── abi/         # Generated ABIs (synced from contracts/out/)
├── public/
├── package.json
├── tailwind.config.ts
├── next.config.js
└── tsconfig.json
```

**Structure Decision**: Single `webapp/` folder at repo root per user request. Uses Atomic Design (CLAUDE.md) and Next.js App Router. Layout and styling based on v0-mandingafront.vercel.app (card grid, filters, status badges, light/dark mode).

## Complexity Tracking

> No constitution violations. Table left empty.
