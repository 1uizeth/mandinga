# Spec 007 — DeFi Dashboard: Research

**Date**: March 2026  
**Status**: Consolidated from user input and v0 reference

---

## Decision 1: Webapp Location — Root `webapp/` Folder

**Decision:** Create a `webapp/` folder at the repository root (not `frontend/`).

**Rationale:** User explicitly requested "build a webapp folder in the root of this project."

**Alternatives considered:** Reusing existing `frontend/` from CLAUDE.md — rejected because user specified new webapp folder.

---

## Decision 2: Stack — Next.js, TypeScript, Viem/Wagmi, Tailwind

**Decision:** Next.js 14 (App Router), TypeScript 5.x, wagmi v2, viem v2, Tailwind CSS.

**Rationale:** Aligns with CLAUDE.md frontend stack; wagmi v2 + viem v2 are the standard for Ethereum in React; Tailwind for styling.

**Alternatives considered:** ethers.js — rejected per CLAUDE.md ("No direct ethers.js — use viem exclusively").

---

## Decision 3: Light and Dark Mode

**Decision:** Support both light and dark themes. Use Tailwind `dark:` variants and a theme provider (e.g., next-themes).

**Rationale:** User requested "Light and Dark mode"; v0 reference supports both.

**Alternatives considered:** Light-only — rejected per user request.

---

## Decision 4: Layout Reference — v0-mandingafront.vercel.app

**Decision:** Base layout and visual style on [v0-mandingafront.vercel.app](https://v0-mandingafront.vercel.app/).

**Rationale:** User specified this reference. Key elements: Mandinga header, "Browse available circles", Sort/Status/Entry filters, card grid with Pay $X/mo, pool amount, status (Ended/Active/Joined), slots left, ENS-style names.

**Layout elements to replicate:**
- Header with Mandinga branding
- Filter bar (Sort by, Status, Entry)
- Card grid for circles
- Status badges (Ended, Active, Joined)
- Pay $X/mo for N months format
- Slots left indicator

---

## Decision 5: Wallet Providers — Injected, MetaMask, WalletConnect

**Decision:** Support Injected Wallet (browser extension), MetaMask, and WalletConnect via wagmi connectors.

**Rationale:** Per spec FR-002, FR-003, FR-004. wagmi v2 supports all via @wagmi/connectors (injected, metaMask, walletConnect).

---

## Decision 6: Component Architecture — Atomic Design

**Decision:** Follow Atomic Design: atoms → molecules → organisms → templates → app pages. Contract hooks only in `hooks/` or `app/` pages.

**Rationale:** Per CLAUDE.md; components receive data as props; no contract fetching inside atoms/molecules/organisms/templates.

---

## Decision 7: UI Primitives — shadcn/ui

**Decision:** Use shadcn/ui for Button, Badge, Input, Card, etc. Integrates with Tailwind and supports dark mode.

**Rationale:** Per CLAUDE.md; shadcn/ui is copy-paste, customizable, and Tailwind-native.

---

## Decision 8: Target Network — Base Sepolia (Testnet)

**Decision:** Default to Base Sepolia for development; support mainnet via config.

**Rationale:** Contracts deploy to Base Sepolia per project config; MockUSDC available on testnet.
