# Spec 007 — DeFi Dashboard: UI Contracts

**Date**: March 2026
**Purpose**: Document the UI/UX contracts the webapp exposes to users. These are behavioral contracts, not smart contracts.

---

## Page Contracts

### 1. Wallet Gate (Entry)

| Contract | Behavior |
|----------|----------|
| WG-001 | App MUST show a wallet connection prompt when user is not connected |
| WG-002 | App MUST NOT expose protocol actions (deposit, circles, etc.) until connected |
| WG-003 | App MUST support Injected Wallet, MetaMask, and WalletConnect |
| WG-004 | App MUST display connected address (truncated) and allow disconnect |
| WG-005 | App MUST handle network mismatch (e.g., prompt switch to Base Sepolia) |

---

### 2. Savings Account View

| Contract | Behavior |
|----------|----------|
| SA-001 | App MUST display total deposited amount in USDC (6 decimals, formatted) |
| SA-002 | App MUST display total shares held |
| SA-003 | App MUST provide a deposit action to activate account |
| SA-004 | On testnet, App MUST display MockUSDC as "USDC" in the UI |
| SA-005 | App MUST show withdrawable amount when applicable |
| SA-006 | App MUST handle zero balance / inactive account state |

---

### 3. Savings Circles View

| Contract | Behavior |
|----------|----------|
| SC-001 | App MUST list all circles the user participates in |
| SC-002 | For each circle, App MUST show: status (Forming/Active/Completed), pool size, contribution per round, duration |
| SC-003 | App MUST show next round date (when joinCircle or round execution is available) |
| SC-004 | App MUST show empty state when user is in no circles |
| SC-005 | App MAY show "Browse circles" to discover/join new circles |
| SC-006 | Status badges MUST be visually distinct (Ended=gray, Active=green, Joined=blue per v0 reference) |

---

### 4. Yield Overview

| Contract | Behavior |
|----------|----------|
| YO-001 | App MUST display cumulative yield earned since first deposit |
| YO-002 | App MUST show zero or empty state when no yield |
| YO-003 | App MAY show yield as USDC amount and/or percentage |
| YO-004 | Display MUST be at a glance (no extra clicks) |

---

## Component Contracts (Atomic Design)

### Atoms

| Component | Props | Behavior |
|-----------|-------|----------|
| Button | variant, size, disabled, onClick | Renders clickable button; supports primary/secondary/ghost |
| Badge | variant (status), children | Renders status badge (Ended, Active, Joined) |
| Input | value, onChange, placeholder, type | Controlled input |
| Label | htmlFor, children | Form label |
| Spinner | size | Loading indicator |
| Icon | name, size | Icon display |

### Molecules

| Component | Props | Behavior |
|-----------|-------|----------|
| TokenAmountDisplay | amount, decimals, symbol | Formats and displays token amount (e.g., "1,234.56 USDC") |
| StatCard | label, value, subValue | Card for single stat |
| WalletConnectButton | — | Connect/disconnect; shows address when connected |

### Organisms

| Component | Props | Behavior |
|-----------|-------|----------|
| SavingsPositionCard | position | Displays balance, shares, deposit/withdraw actions |
| CircleStatusPanel | circle, userSlot | Displays circle details, status, next round |
| AppHeader | — | Logo, nav, wallet button, theme toggle |

### Templates

| Template | Slots | Behavior |
|----------|-------|----------|
| DashboardTemplate | header, main | Layout for dashboard pages |
| CircleTemplate | header, filters, cardGrid | Layout for circles browse/detail |

---

## Error Handling Contracts

| Contract | Behavior |
|----------|----------|
| EH-001 | RPC errors MUST show user-friendly message and retry option |
| EH-002 | Insufficient balance MUST prevent transaction and show clear message |
| EH-003 | Transaction rejection (user cancel) MUST not show as error |
| EH-004 | Disconnected wallet MUST prompt reconnection |
