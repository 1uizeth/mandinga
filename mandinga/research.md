# Mandinga Protocol — Research

**Generated:** February 2026
**Context:** Monorepo structure decision — `backend/` (Foundry/Solidity) + `frontend/` (Next.js)

---

## Decision 1: Monorepo Layout

**Decision:** Two-root monorepo with `backend/` and `frontend/` at repo root level.

**Rationale:** The Chainlink CRE template (`stablecoin-ace-ccip`) establishes a clean separation between the on-chain layer (Foundry project) and off-chain layers. Mandinga adopts the same pattern with `backend/` as the Foundry root and `frontend/` as the Next.js root. Each sub-project is independently buildable and deployable.

**Alternatives considered:**
- Single Foundry root with `frontend/` nested → rejected: pollutes Foundry root with Next.js dependencies
- Turborepo/nx monorepo tooling → deferred: adds complexity not needed at this stage

---

## Decision 2: Backend — `contracts/` as Solidity Source Directory

**Decision:** Use `contracts/` (not `src/`) as the Solidity source directory inside `backend/`. `foundry.toml` sets `src = "contracts"`.

**Rationale:** The CRE template uses this convention (`foundry.toml` → `src = "contracts"`). It is also semantically clearer in a monorepo where `src/` would be ambiguous between Solidity and TypeScript.

**Reference:** `smartcontractkit/cre-templates` foundry.toml:
```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["node_modules", "lib"]
```

**Alternatives considered:**
- `src/` (Foundry default) → rejected for semantic clarity in monorepo context

---

## Decision 3: Backend — Dependency Management

**Decision:** Use Foundry git submodules (`lib/`) for Solidity dependencies. `npm` used only for OpenZeppelin (`node_modules`), matching CRE template pattern (`libs = ["node_modules", "lib"]`).

**Rationale:** Mirrors CRE template. Keeps Solidity deps auditable and pinned via `foundry.lock`.

**Key dependencies:**
- `lib/forge-std` — Foundry test utilities
- `lib/openzeppelin-contracts` — OZ Contracts v5
- `lib/openzeppelin-foundry-upgrades` — OZ Upgrades for Foundry
- `node_modules/@openzeppelin/contracts` — for remapping compatibility

---

## Decision 4: Frontend — Next.js 14 App Router

**Decision:** Next.js 14 with App Router (`src/app/`). No Pages Router.

**Rationale:** App Router is the current Next.js standard (2024–2026). Server Components reduce bundle size for a mobile-first PWA. `app/` directory enables route-based code splitting naturally.

**Alternatives considered:**
- React Native / Expo → deferred to v2 (mobile app); v1 targets PWA via Next.js
- Vite + React SPA → rejected: no SSR, worse PWA/SEO baseline

---

## Decision 5: Frontend — Web3 Stack

**Decision:** `wagmi` v2 + `viem` v2 for Ethereum interactions.

**Rationale:** `viem` is already used in the CRE template workflows (`import { encodeAbiParameters } from 'viem'`). `wagmi` v2 is built on `viem` and provides React hooks for wallet connection, contract reads/writes, and transaction state. Industry standard for Next.js + Ethereum in 2026.

**Key packages:**
- `wagmi` — React hooks for Ethereum
- `viem` — TypeScript Ethereum library (replaces ethers.js)
- `@rainbow-me/rainbowkit` or `connectkit` — wallet connection UI
- `@tanstack/react-query` — required by wagmi v2

**Alternatives considered:**
- `ethers.js` v6 → rejected: viem has better TypeScript support and is CRE template native
- `web3.js` → rejected: deprecated trajectory

---

## Decision 6: ABI Sharing Strategy

**Decision:** Forge build artifacts (`backend/out/`) are gitignored. A `make abi` or `npm run sync-abi` script copies generated ABI JSON from `backend/out/` to `frontend/src/lib/abi/`. ABIs are committed to the frontend repo.

**Rationale:** Frontend needs stable ABI references. Committing generated ABIs ensures the frontend always has a known-good ABI snapshot. The sync script is run after any contract interface change.

**File mapping:**
```
backend/out/SavingsAccount.sol/SavingsAccount.json  →  frontend/src/lib/abi/SavingsAccount.ts
backend/out/SavingsCircle.sol/SavingsCircle.json    →  frontend/src/lib/abi/SavingsCircle.ts
...
```

---

## Decision 7: Frontend — UI Component Strategy

**Decision:** `shadcn/ui` (Radix UI primitives + Tailwind CSS) as the component foundation.

**Rationale:** Mobile-first, accessible, composable. Radix UI primitives handle keyboard navigation and ARIA out of the box. Tailwind enables rapid responsive design without a dedicated design system at this stage.

**Alternatives considered:**
- Chakra UI → rejected: heavier runtime, less flexible
- Material UI → rejected: opinionated desktop-first design language

---

## Decision 9: Frontend — Component Architecture (Atomic Design)

**Decision:** Atomic Design methodology for the `components/` directory: `atoms/` → `molecules/` → `organisms/` → `templates/`.

**Rationale:** Mandinga's UI has a clear composition hierarchy — small reusable primitives (Button, Badge, TokenAmount) compose into functional units (StatCard, PositionRow) which compose into domain sections (PositionPanel, CircleStatusPanel) which compose into full page layouts (DashboardTemplate). Atomic Design makes these composition layers explicit and enforces single-responsibility at each level. It also aligns with how shadcn/ui components are designed (atomic primitives).

In Next.js 14 App Router, the `app/` pages serve as the **Pages** level of Atomic Design — they instantiate Templates with real data from wagmi hooks. This keeps pages thin and testable.

**Layer mapping for Mandinga:**

| Atomic Level | `components/` folder | Examples |
|---|---|---|
| Atoms | `atoms/` | `Button`, `Badge`, `Input`, `Label`, `Spinner`, `Icon`, `Avatar`, `Tooltip` |
| Molecules | `molecules/` | `TokenAmountDisplay`, `StatCard`, `FormField`, `WalletConnectButton`, `TransactionStatus`, `CountdownTimer` |
| Organisms | `organisms/` | `SavingsPositionCard`, `CircleStatusPanel`, `VouchCard`, `AppHeader`, `BottomNav`, `YieldMetricsPanel` |
| Templates | `templates/` | `DashboardTemplate`, `CircleTemplate`, `SolidarityTemplate` (layouts with slot props, no real data) |
| Pages | `app/**/page.tsx` | Compose Templates + wagmi hooks → full pages |

**Rules enforced:**
- Atoms have no dependencies on other `components/` — only on design tokens and shadcn/ui primitives
- Molecules depend only on Atoms
- Organisms may depend on Atoms and Molecules, but not on Templates or Pages
- Templates accept only typed slot props (no direct contract reads inside templates)
- All contract reads and writes live in `hooks/` or in `app/` pages, never inside Atoms/Molecules/Organisms directly

**Alternatives considered:**
- Feature-based folder structure (`components/savings/`, `components/circle/`) → rejected: leads to duplication of shared primitives and makes cross-feature reuse harder
- Flat `components/` with no sub-structure → rejected: does not scale past ~20 components

---

## Decision 10: Yield Engine — Aave V3 Only (v1)

**Decision:** v1 uses a single yield source: Aave V3. `OndoAdapter` (real-world yield) and `OracleAggregator` (multi-source rate aggregation) are deferred to v2.

**Rationale:** Real-world yield sources (Ondo OUSG, Superstate) require a KYC relationship at the protocol entity level, legal structure work, and compliance overhead that is out of scope for v1. Removing them eliminates `OracleAggregator` (which was only needed to compare multi-source rates), `OndoAdapter`, and all allocation-weight/rebalance logic. The `YieldRouter` simplifies significantly: it has exactly one adapter, routes 100% of deposits to Aave V3, and harvests Aave's native aToken yield.

**Impact on spec:**
- Spec 004 AC-001-2 ("at minimum 2 yield sources") → closed as v1 simplification; deferred to v2
- Spec 004 US-002 ("Real-World Yield Sources") → deferred to v2 in its entirety
- Spec 004 US-003 ("Oracle Integration") → simplified: no multi-source median; circuit breaker uses Aave's own utilization/liquidity signals
- Task 004-02 (OracleAggregator) → status: Deferred to v2
- YieldRouter no longer depends on OracleAggregator (task-04 unblocked from task-02)

**What stays:**
- `AaveAdapter.sol` — wraps Aave V3 `IPool`, deposits/withdraws USDC, harvests aToken yield
- `YieldRouter.sol` — ERC4626 meta-vault; routes all capital to `AaveAdapter`; harvest → fee + buffer + share price appreciation
- `IYieldSourceAdapter` interface — kept for v2 adapter extensibility
- Circuit breaker — simplified: checks Aave's aToken liquidity availability; blocks withdrawals only if Aave liquidity is critically low (not rebalance, since there's nothing to rebalance)

**Alternatives considered:**
- Keep OracleAggregator but with only 1 feed → rejected: OracleAggregator was designed for multi-source median, its logic degrades to trivial with 1 source; just read Aave's rate directly
- Keep OndoAdapter as a stub → rejected: adds dead code and audit surface

---

## Decision 8: Chainlink CRE Workflows — Superseded by Spec 006

**Original decision:** Mandinga v1 does not use Chainlink CRE DON-signed workflows.

**Superseded (March 2026):** Spec 006 — Automation Layer includes CRE workflows in v1. DON deployment and ACE configuration are part of the v1 release. See `mandinga/specs/006-automation/spec.md` for the four CRE use cases (circle formation cron, Safety Pool monitor, reallocation trigger, yield harvest).

---

## Resolved Clarifications

| # | Question | Resolution |
|---|---|---|
| RC-001 | Solidity source dir convention | `contracts/` (not `src/`) — matches CRE template |
| RC-002 | Frontend framework | Next.js 14 App Router |
| RC-003 | Web3 library | wagmi v2 + viem v2 |
| RC-004 | Wallet UI | rainbowkit or connectkit (to be decided at implementation) |
| RC-005 | ABI sharing | Forge build → sync script → `frontend/src/lib/abi/` |
| RC-006 | CRE workflows | **Superseded** — Spec 006 includes CRE in v1 |
