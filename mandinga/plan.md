# Mandinga Protocol — Technical Plan

**Version:** 0.2
**Date:** February 2026
**Status:** Draft — privacy layer deferred to v2 (see constitution.md §2.3 and Spec 005)

---

## 1. Architecture Overview

Mandinga Protocol is a four-layer system:

```
┌─────────────────────────────────────────────────────────┐
│               FRONTEND LAYER (frontend/)                │
│   Next.js 14 App Router · Mobile-first PWA              │
│   wagmi v2 + viem v2 · No KYC · Wallet-connect         │
└─────────────────────────┬───────────────────────────────┘
                          │  ABI + contract calls
┌─────────────────────────▼───────────────────────────────┐
│   PRIVACY LAYER — Deferred to v2 (see §4)               │
│   v1: shieldedId pseudonymity only                      │
└──────┬────────────────────────────────────┬─────────────┘
       │                                    │
┌──────▼──────────────┐         ┌──────────▼──────────────┐
│   CORE CONTRACTS    │         │   YIELD ENGINE          │
│                     │         │                         │
│  SavingsAccount     │         │  YieldRouter            │
│  SavingsCircle      │         │  YieldSourceAdapter     │
│  SolidarityMarket   │         │  OracleAggregator       │
│  CircleBuffer       │         │  FeeCollector           │
└──────────┬──────────┘         └──────────┬──────────────┘
           │                               │
┌──────────▼───────────────────────────────▼──────────────┐
│              EXTERNAL INTEGRATIONS                      │
│                                                         │
│  Chainlink VRF (selection randomness)                  │
│  Chainlink Data Feeds (yield rate oracles)             │
│  Aave / Compound (DeFi yield source)                   │
│  Ondo / Superstate (real-world yield source)           │
│  USDC (ERC-20 dollar-stable asset)                     │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Repository Structure

Monorepo with `backend/` (Foundry) and `frontend/` (Next.js). Structure follows the Chainlink CRE template convention: `contracts/` is the Solidity source directory (`src = "contracts"` in foundry.toml). No Hardhat, no TypeScript test or deploy toolchain in backend.

```
mandinga-protocol/
├── backend/                           (Foundry project root)
│   ├── contracts/                     (Solidity sources — src = "contracts" in foundry.toml)
│   │   ├── core/
│   │   │   ├── SavingsAccount.sol
│   │   │   ├── SavingsCircle.sol
│   │   │   ├── SolidarityMarket.sol
│   │   │   └── CircleBuffer.sol
│   │   ├── yield/
│   │   │   ├── YieldRouter.sol
│   │   │   └── AaveAdapter.sol          (sole adapter in v1)
│   │   ├── governance/
│   │   │   └── MandigaGovernor.sol
│   │   └── interfaces/
│   │       ├── ISavingsAccount.sol
│   │       ├── ISavingsCircle.sol
│   │       ├── ISolidarityMarket.sol
│   │       ├── IYieldRouter.sol
│   │       └── IYieldSourceAdapter.sol  (adapter pattern — v2 adds OndoAdapter etc.)
│   ├── script/
│   │   ├── DeployYieldEngine.s.sol
│   │   ├── DeploySavingsAccount.s.sol
│   │   ├── DeploySavingsCircle.s.sol
│   │   └── DeploySolidarityMarket.s.sol
│   ├── test/
│   │   ├── unit/
│   │   │   ├── SavingsAccount.t.sol
│   │   │   ├── SavingsCircle.t.sol
│   │   │   ├── SolidarityMarket.t.sol
│   │   │   └── YieldRouter.t.sol
│   │   ├── integration/
│   │   │   ├── FullCircleLifecycle.t.sol
│   │   │   ├── VouchAndSelection.t.sol
│   │   │   └── EmergencyExit.t.sol
│   │   └── invariant/
│   │       └── BalanceInvariants.t.sol    (Foundry invariant/fuzz tests)
│   ├── lib/                           (Foundry git submodule dependencies)
│   │   ├── forge-std/
│   │   ├── openzeppelin-contracts/
│   │   └── openzeppelin-foundry-upgrades/
│   ├── out/                           (build artifacts — gitignored)
│   ├── foundry.toml
│   ├── .env.example
│   ├── .gitmodules
│   └── Makefile                       (forge build, forge test, sync-abi)
│
├── frontend/                          (Next.js 14 App Router — Atomic Design)
│   ├── src/
│   │   ├── app/                       (Pages level — thin, composes Templates + hooks)
│   │   │   ├── layout.tsx             (root layout: wagmi provider, wallet modal)
│   │   │   ├── page.tsx               (dashboard — composes DashboardTemplate)
│   │   │   ├── savings/
│   │   │   │   └── page.tsx           (savings account detail)
│   │   │   ├── circle/
│   │   │   │   └── [circleId]/
│   │   │   │       └── page.tsx       (circle status + round countdown)
│   │   │   └── solidarity/
│   │   │       └── page.tsx           (solidarity market browse + vouch)
│   │   │
│   │   ├── components/
│   │   │   ├── atoms/                 (indivisible primitives — no contract deps)
│   │   │   │   ├── Button.tsx
│   │   │   │   ├── Badge.tsx
│   │   │   │   ├── Input.tsx
│   │   │   │   ├── Label.tsx
│   │   │   │   ├── Spinner.tsx
│   │   │   │   ├── Icon.tsx
│   │   │   │   ├── Avatar.tsx
│   │   │   │   └── Tooltip.tsx
│   │   │   │
│   │   │   ├── molecules/             (atoms composed into functional units)
│   │   │   │   ├── TokenAmountDisplay.tsx   (formatted USDC amount + label)
│   │   │   │   ├── StatCard.tsx             (label + value + optional trend)
│   │   │   │   ├── FormField.tsx            (Label + Input + error message)
│   │   │   │   ├── WalletConnectButton.tsx  (connect/disconnect + address display)
│   │   │   │   ├── TransactionStatus.tsx    (pending / success / error state)
│   │   │   │   └── CountdownTimer.tsx       (next round countdown)
│   │   │   │
│   │   │   ├── organisms/             (domain sections — atoms + molecules only)
│   │   │   │   ├── SavingsPositionCard.tsx  (balance, locked, withdrawable, APY)
│   │   │   │   ├── DepositWithdrawPanel.tsx (deposit/withdraw form + tx flow)
│   │   │   │   ├── YieldMetricsPanel.tsx    (blended APY, total allocated)
│   │   │   │   ├── CircleStatusPanel.tsx    (status, slots, round progress)
│   │   │   │   ├── VouchCard.tsx            (vouch details + interest claim)
│   │   │   │   ├── AppHeader.tsx            (logo + wallet connect + nav)
│   │   │   │   └── BottomNav.tsx            (mobile tab bar)
│   │   │   │
│   │   │   └── templates/             (page layouts — slot props, no real data)
│   │   │       ├── DashboardTemplate.tsx    (header + position + yield slots)
│   │   │       ├── CircleTemplate.tsx       (header + circle status + history slots)
│   │   │       └── SolidarityTemplate.tsx   (header + vouch list + create vouch slots)
│   │   │
│   │   ├── hooks/                     (wagmi contract hooks — used by pages only)
│   │   │   ├── useSavingsAccount.ts
│   │   │   ├── useSavingsCircle.ts
│   │   │   ├── useYieldRouter.ts
│   │   │   └── useSolidarityMarket.ts
│   │   │
│   │   ├── lib/
│   │   │   ├── contracts.ts           (contract addresses per chain)
│   │   │   ├── wagmi.ts               (wagmi + viem config)
│   │   │   ├── abi/                   (generated from backend/out/ — committed)
│   │   │   │   ├── SavingsAccount.ts
│   │   │   │   ├── SavingsCircle.ts
│   │   │   │   ├── YieldRouter.ts
│   │   │   │   └── SolidarityMarket.ts
│   │   │   └── utils.ts
│   │   │
│   │   └── types/                     (shared TypeScript types)
│   │       ├── contracts.ts           (Position, Circle, Vouch types mirroring Solidity structs)
│   │       └── ui.ts
│   │
│   ├── public/
│   ├── next.config.ts
│   ├── tailwind.config.ts
│   ├── tsconfig.json
│   └── package.json
│
├── docs/
│   ├── architecture.md
│   └── yield-sources.md
└── audits/                            (to be populated pre-mainnet)
```

### Frontend — Atomic Design Rules

| Level | Folder | Allowed dependencies | Contract access |
|---|---|---|---|
| Atoms | `components/atoms/` | shadcn/ui primitives, Tailwind, design tokens only | None |
| Molecules | `components/molecules/` | Atoms only | None |
| Organisms | `components/organisms/` | Atoms + Molecules | None (receive data via props) |
| Templates | `components/templates/` | Organisms + Molecules + Atoms | None (slot props only) |
| Pages | `app/**/page.tsx` | Templates + `hooks/` | Via wagmi hooks |

Contract reads and writes **only** in `hooks/` or directly in `app/` pages. No `useReadContract` or `useWriteContract` inside Atoms, Molecules, Organisms, or Templates.

---

### `backend/foundry.toml`

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib", "node_modules"]
remappings = [
  "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
  "@openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/",
  "forge-std/=lib/forge-std/src/"
]

[rpc_endpoints]
arbitrum_sepolia = "${ARBITRUM_SEPOLIA_RPC_URL}"
base_sepolia     = "${BASE_SEPOLIA_RPC_URL}"
mainnet          = "${MAINNET_RPC_URL}"

[etherscan]
arbitrum_sepolia = { key = "${ARBISCAN_API_KEY}" }
base_sepolia     = { key = "${BASESCAN_API_KEY}" }
```

### ABI Sync (`backend/Makefile`)

```makefile
sync-abi:
	forge build
	cp out/SavingsAccount.sol/SavingsAccount.json ../frontend/src/lib/abi/SavingsAccount.json
	cp out/SavingsCircle.sol/SavingsCircle.json   ../frontend/src/lib/abi/SavingsCircle.json
	cp out/YieldRouter.sol/YieldRouter.json       ../frontend/src/lib/abi/YieldRouter.json
	cp out/SolidarityMarket.sol/SolidarityMarket.json ../frontend/src/lib/abi/SolidarityMarket.json
```

---

## 3. Smart Contract Design

### 3.1 SavingsAccount.sol

The foundational state store. Designed to be as minimal as possible — it stores position data and enforces the principal lock. Yield accrual logic is delegated to the YieldRouter.

**Key state:**
```solidity
struct Position {
    uint256 balance;           // Total balance (principal + accrued yield)
    uint256 circleObligation;  // Minimum balance that cannot be withdrawn
    uint256 lastYieldUpdate;   // Block timestamp of last yield credit
    bool circleActive;         // Whether circle participation is active
    bool vouchActive;          // Whether an outgoing vouch is active
}

mapping(bytes32 => Position) private positions;  // shieldedId => Position
```

**Key invariant enforced at every state transition:**
```solidity
require(position.balance >= position.circleObligation, "PRINCIPAL_LOCK");
```

**Emergency exit:**
- Controlled by `EmergencyModule` with a 7-day timelock
- In emergency state, `circleObligation` is set to 0 for all positions; full balance becomes withdrawable

### 3.2 SavingsCircle.sol

Manages circle lifecycle: creation, member assignment, round execution, selection, and completion.

**Key state:**
```solidity
struct Circle {
    uint256 poolSize;
    uint256 contributionPerMember;
    uint8 memberCount;
    uint8 roundsCompleted;
    uint8 totalRounds;
    uint256 roundDuration;       // in seconds
    uint256 nextRoundTimestamp;
    CircleStatus status;         // FORMING | ACTIVE | COMPLETED | EMERGENCY
    mapping(uint8 => bytes32) members;      // slot => shieldedId
    mapping(bytes32 => uint8) memberSlots;  // shieldedId => slot
    mapping(uint8 => bool) payoutReceived;  // slot => has received payout
    mapping(uint8 => bool) positionPaused; // slot => is paused
}
```

**Selection flow:**
1. Round end timestamp reached → `executeRound()` called (anyone can call — no trusted executor)
2. Request randomness from Chainlink VRF
3. VRF callback → select eligible (non-paused, not-yet-paid) member from random seed
4. Transfer pool amount to selected member's SavingsAccount (increases their balance AND circleObligation)
5. Emit `MemberSelected` event (member identity shielded — event contains only circle ID and round number)

### 3.3 SolidarityMarket.sol

Manages vouch creation, income distribution, and expiry.

**Key state:**
```solidity
struct Vouch {
    bytes32 voucherId;      // shieldedId of voucher
    bytes32 vouchedId;      // shieldedId of vouched member
    uint256 amount;         // locked vouch amount
    uint256 interestRate;   // bps per year
    uint256 payoutShareBps; // voucher's share of payout differential
    uint256 startTimestamp;
    uint256 circleId;       // associated circle
    VouchStatus status;     // ACTIVE | PAUSED | COMPLETED | EXPIRED
}
```

**Income distribution:**
- Interest: continuously accrued per block, claimable anytime
- Payout share: automatically distributed at the `MemberSelected` event via `SavingsCircle` callback

### 3.4 YieldRouter.sol

Routes capital across yield sources. Uses an adapter pattern so new sources can be added by governance without contract upgrades.

**Key functions (v1 — single Aave adapter):**
```solidity
function deposit(uint256 assets, address receiver) external returns (uint256 shares);  // ERC4626
function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);  // ERC4626
function harvest() external;                  // collect Aave yield; raise share price
function getBlendedAPY() external view returns (uint256);  // Aave V3 USDC supply rate
```

**Circuit breaker (v1):**
- If Aave available liquidity drops below governance-set threshold, `harvest()` is paused
- `deposit()` and `withdraw()` always available — circuit breaker never blocks exits

---

## 4. Privacy Architecture

**Status: Deferred to v2.** See `constitution.md` §2.3 for the full decision record.

v1 uses `shieldedId = keccak256(abi.encodePacked(msg.sender, nonce))` as a pseudonymous identifier. All contracts use `bytes32 shieldedId` in state and interfaces to preserve the v2 migration path. No ZK circuits, verifier contracts, or FHE dependencies in v1.

Technology candidates for v2 (Aztec, Circom/Noir, Zama fhEVM/CoFHE) are documented in Spec 005.

---

## 5. Build Order and Milestones

### Milestone 0: Toolchain Setup (Week 1–2)
- [ ] Initialise Foundry repo (`forge init`); configure `foundry.toml`
- [ ] Add OpenZeppelin Contracts v5 and OpenZeppelin Foundry Upgrades as dependencies
- [ ] Deploy dummy contract to testnet to validate toolchain and Forge script broadcast

### Milestone 1: Yield Engine (Weeks 3–6)
- [ ] `backend/contracts/interfaces/IYieldRouter.sol` — ERC4626 interface
- [ ] `backend/contracts/interfaces/IYieldSourceAdapter.sol` — adapter interface (extensible for v2)
- [ ] `backend/contracts/yield/AaveAdapter.sol` — Aave V3 integration (sole adapter in v1)
- [ ] `backend/contracts/yield/YieldRouter.sol` — ERC4626 meta-vault; single-adapter deposit/harvest
- [ ] `backend/test/unit/AaveAdapter.t.sol` — fork tests against Arbitrum (`forge test --fork-url`)
- [ ] `backend/test/unit/YieldRouter.t.sol` — unit tests with mock AaveAdapter
- [ ] `backend/script/DeployYieldEngine.s.sol` — Forge deploy script
- [ ] Testnet deployment via `forge script --broadcast`
- [ ] `make sync-abi` to export ABIs to `frontend/src/lib/abi/`

### Milestone 2: Savings Account (Weeks 7–12)
- [ ] `backend/contracts/interfaces/ISavingsAccount.sol` interface
- [ ] `backend/contracts/core/SavingsAccount.sol` — deposit, withdraw, principal lock, `shieldedId` pseudonymity
- [ ] Integration with YieldRouter (ERC4626 share accounting)
- [ ] `backend/contracts/core/EmergencyModule.sol` — timelock-gated emergency exit
- [ ] `backend/test/unit/SavingsAccount.t.sol` — unit tests
- [ ] `backend/test/invariant/BalanceInvariants.t.sol` — Foundry invariant fuzz testing (`sharesBalance >= circleObligationShares`)
- [ ] `backend/script/DeploySavingsAccount.s.sol` — Forge deploy script
- [ ] Testnet deployment
- [ ] `frontend/`: savings dashboard page with `useSavingsAccount` hook — balance, APY, withdraw

### Milestone 3: Savings Circle (Weeks 13–20)
- [ ] `backend/contracts/interfaces/ISavingsCircle.sol` interface
- [ ] `backend/contracts/core/CircleBuffer.sol` — yield smoothing buffer
- [ ] `backend/contracts/core/SavingsCircle.sol` — circle lifecycle, round execution
- [ ] Chainlink VRF integration — selection randomness
- [ ] `backend/test/unit/SavingsCircle.t.sol` — unit tests
- [ ] `backend/test/integration/FullCircleLifecycle.t.sol` — full lifecycle integration test
- [ ] `backend/script/DeploySavingsCircle.s.sol` — Forge deploy script
- [ ] Testnet deployment and multi-week testnet circle run
- [ ] `frontend/`: circle status page with `useSavingsCircle` hook

### Milestone 4: Solidarity Market (Weeks 21–28)
- [ ] `backend/contracts/interfaces/ISolidarityMarket.sol` interface
- [ ] `backend/contracts/core/SolidarityMarket.sol` — vouch creation, income distribution
- [ ] `backend/test/unit/SolidarityMarket.t.sol` — unit tests
- [ ] `backend/test/integration/VouchAndSelection.t.sol` — end-to-end vouch + circle + selection test
- [ ] `backend/script/DeploySolidarityMarket.s.sol` — Forge deploy script
- [ ] Testnet deployment
- [ ] `frontend/`: solidarity market browse and vouch interface

### Milestone 5: Governance and Security (Weeks 29–36)
- [ ] `backend/contracts/governance/MandigaGovernor.sol` — one-member-one-vote governance
- [ ] Governance parameters (fee rate, buffer reserve %)
- [ ] External security audit (all contracts)
- [ ] Bug bounty program launch
- [ ] Formal verification of core invariants (`sharesBalance >= circleObligationShares`)

### Milestone 6: Frontend Polish (Weeks 20–36, parallel with M4/M5)

**Atomic Design build order (atoms → molecules → organisms → templates → pages):**

- [ ] **Atoms:** `Button`, `Badge`, `Input`, `Label`, `Spinner`, `Icon`, `Tooltip` (shadcn/ui wrappers)
- [ ] **Molecules:** `TokenAmountDisplay`, `StatCard`, `FormField`, `WalletConnectButton`, `TransactionStatus`, `CountdownTimer`
- [ ] **Organisms:** `SavingsPositionCard`, `DepositWithdrawPanel`, `YieldMetricsPanel`, `CircleStatusPanel`, `VouchCard`, `AppHeader`, `BottomNav`
- [ ] **Templates:** `DashboardTemplate`, `CircleTemplate`, `SolidarityTemplate`
- [ ] **Pages + hooks:** `app/` pages composing templates with `useSavingsAccount`, `useSavingsCircle`, `useYieldRouter`, `useSolidarityMarket`
- [ ] Wallet connect (RainbowKit or ConnectKit) — multi-chain support (Arbitrum, Base, Optimism)
- [ ] Mobile-first responsive design (Tailwind + shadcn/ui)
- [ ] PWA manifest and offline support
- [ ] Accessibility audit (WCAG 2.1 AA target)

### Milestone 7: Mainnet Launch (Week 37+)
- [ ] Audit remediations complete
- [ ] Governance multisig established
- [ ] Emergency procedures tested
- [ ] Mainnet deployment
- [ ] Public launch — limited initial TVL cap

---

## 6. Data Flow: Full Circle Lifecycle

```
Member A deposits $200 USDC
  → SavingsAccount.deposit(200e6)
  → YieldRouter.allocate(200e6)  [routes to Aave + Ondo]
  → Position{sharesBalance: <shares>, circleObligationShares: 0} created under shieldedId

Member activates circle participation
  → SavingsAccount.activateCircle()
  → Contract checks sharesBalance >= minContributionShares (on-chain, plaintext in v1)
  → SavingsCircle.joinCircle(circleId)  [matched by protocol to appropriate tier]
  → 9 other members join same circle

Round 1 executes (anyone calls executeRound())
  → Chainlink VRF request
  → VRF callback: Member C selected
  → SavingsAccount[C].balance += 2000 (full pool)
  → SavingsAccount[C].circleObligation += 2000
  → YieldRouter.allocate(2000) [full pool now earning yield for Member C]
  → SolidarityMarket notified if Member C has a voucher → voucher payout share sent

Rounds 2–9 execute similarly
  → Each non-selected member's obligation is settled automatically
  → Member A's circleObligation increases by 200 each round until settled

Round 10: Member A selected
  → Member A receives full pool payout
  → All prior obligations settled

Circle completes
  → All circleObligations reset to 0
  → All members' balances reflect earned yield
  → Members offered: join new circle or return to standalone
```

---

## 7. Security Considerations

### Reentrancy
All fund-moving functions follow checks-effects-interactions. No external calls before state updates. `ReentrancyGuard` on all entry points.

### Access Control
- No admin functions that can move user funds (only governance with 7-day timelock)
- `executeRound()` is permissionless — any address can trigger it; output is determined by VRF, not the caller
- Yield adapter upgrades require governance vote + 7-day timelock

### Oracle Manipulation
- Two independent oracle sources minimum
- Circuit breaker at 20% deviation
- Conservative fallback rate (floor) when oracle is stale

### Privacy Failure Modes
- If ZK proof system is compromised, balances may be visible but funds are safe (proof compromise ≠ fund theft)
- Emergency exit path does not require ZK proofs — it is always available

### Economic Attacks
- No flash loan attack surface: all positions require minimum holding periods
- Buffer reserve prevents manipulation through induced member pausing
- 80% vouch diversification floor prevents voucher concentration attacks

---

## 8. Dependencies and External Risks

| Dependency | Risk | Mitigation |
|---|---|---|
| Chainlink VRF | Outage delays selection | Round execution retries; emergency manual selection via DAO vote after 72h outage |
| Chainlink Data Feeds | Stale/manipulated rates | Circuit breaker + conservative fallback rate |
| Aave V3 | Protocol exploit | Single adapter in v1 — full TVL exposure; mitigated by circuit breaker on low liquidity and emergency exit path |
| USDC | De-peg or freeze | Protocol governance can add USDT, DAI support within 1 governance cycle |
| Privacy layer (v2) | Technology not production-ready | Deferred to v2; `shieldedId` abstraction preserves migration path |
