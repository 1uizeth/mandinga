# Commons Protocol — Technical Plan

**Version:** 0.1
**Date:** February 2026
**Status:** Draft — awaiting privacy layer architecture decision (OQ-001 in Spec 005)

---

## 1. Architecture Overview

Commons Protocol is a four-layer system:

```
┌─────────────────────────────────────────────────────────┐
│                   FRONTEND LAYER                        │
│   Mobile-first PWA / React Native                       │
│   No account creation. No KYC. Wallet-connect entry.   │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│                  PRIVACY LAYER                          │
│   ZK proof generation (client-side)                    │
│   Shielded state management (Aztec / zkSync / custom)  │
│   Balance range proofs for contract calls              │
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

```
commons-protocol/
├── contracts/
│   ├── core/
│   │   ├── SavingsAccount.sol
│   │   ├── SavingsCircle.sol
│   │   ├── SolidarityMarket.sol
│   │   └── CircleBuffer.sol
│   ├── yield/
│   │   ├── YieldRouter.sol
│   │   ├── AaveAdapter.sol
│   │   ├── OndoAdapter.sol
│   │   └── OracleAggregator.sol
│   ├── privacy/
│   │   ├── BalanceVerifier.sol        (ZK verifier — auto-generated from circuit)
│   │   ├── MembershipVerifier.sol
│   │   └── HistoryVerifier.sol
│   ├── governance/
│   │   └── CommonsGovernor.sol
│   └── interfaces/
│       ├── ISavingsAccount.sol
│       ├── ISavingsCircle.sol
│       ├── ISolidarityMarket.sol
│       └── IYieldRouter.sol
├── circuits/                          (ZK circuits — Circom or Noir)
│   ├── balance_range.circom
│   ├── membership.circom
│   └── savings_history.circom
├── scripts/
│   ├── deploy/
│   │   ├── 01_deploy_yield_engine.ts
│   │   ├── 02_deploy_savings_account.ts
│   │   ├── 03_deploy_savings_circle.ts
│   │   └── 04_deploy_solidarity_market.ts
│   └── verify/
│       └── verify_invariants.ts
├── test/
│   ├── unit/
│   │   ├── SavingsAccount.test.ts
│   │   ├── SavingsCircle.test.ts
│   │   ├── SolidarityMarket.test.ts
│   │   └── YieldRouter.test.ts
│   ├── integration/
│   │   ├── full_circle_lifecycle.test.ts
│   │   ├── vouch_and_selection.test.ts
│   │   └── emergency_exit.test.ts
│   └── invariant/
│       └── balance_invariants.test.ts  (fuzz/property tests)
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── proofs/                    (client-side ZK proof generation)
│   │   └── pages/
│   └── public/
├── docs/
│   ├── architecture.md
│   └── yield-sources.md
└── audits/                            (to be populated pre-mainnet)
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

**Key functions:**
```solidity
function allocate(uint256 amount) external;   // deposit to yield sources per allocation weights
function harvest() external;                  // collect accrued yield from all sources
function rebalance() external;                // adjust allocation to match target weights
function getBlendedAPY() external view returns (uint256);
```

**Circuit breaker:**
- If oracle deviation > 20%, `rebalance()` is paused
- `allocate()` and `harvest()` continue — no interruption to deposits or yield collection
- Withdrawals always enabled regardless of circuit breaker state

---

## 4. Privacy Architecture

**Recommended approach (pending final decision): Aztec Protocol**

Rationale:
- Aztec is a native privacy L2 built on ZK proofs — the only production L2 designed specifically for private state
- It supports programmable private state (account balances that are shielded) and public/private function calls
- Balance range proofs are first-class functionality in Aztec's Noir language
- The maturity risk is real, but the alternatives (custom ZK circuits) have higher engineering cost and audit surface

**Implementation approach if Aztec is chosen:**
- `SavingsAccount`, `SolidarityMarket`, and `SavingsCircle` deployed as Aztec contracts with private state
- `YieldRouter` deployed on Ethereum/L2 (yield routing can be public — it doesn't reveal individual balances)
- Cross-layer communication: Aztec's L1↔L2 message passing for yield credits

**Fallback approach if Aztec is not ready:**
- Deploy core contracts on Ethereum L2 (Arbitrum or Base) with RAILGUN integration for balance shielding
- Use Circom circuits for balance range proofs, compiled to Groth16, with on-chain Solidity verifier
- Accept slightly weaker privacy guarantees (UTXO-model privacy vs. account-model privacy)

---

## 5. Build Order and Milestones

### Milestone 0: Architecture Decision (Week 1–2)
- [ ] Resolve OQ-001 (Spec 005): Privacy layer technology decision
- [ ] Set up monorepo with Hardhat/Foundry, TypeScript toolchain
- [ ] Deploy dummy contracts to testnet to validate toolchain

### Milestone 1: Yield Engine (Weeks 3–6)
- [ ] `IYieldRouter` interface
- [ ] `AaveAdapter.sol` — Aave V3 integration
- [ ] `OracleAggregator.sol` — Chainlink Data Feeds integration
- [ ] `YieldRouter.sol` — allocation and harvesting logic
- [ ] Unit tests with mock Aave and mock Chainlink
- [ ] Testnet deployment with real Aave testnet

### Milestone 2: Savings Account (Weeks 7–12)
- [ ] `ISavingsAccount.sol` interface
- [ ] ZK balance range circuit (`balance_range.circom`)
- [ ] `BalanceVerifier.sol` — on-chain verifier (generated from circuit)
- [ ] `SavingsAccount.sol` — deposit, withdraw, principal lock
- [ ] Integration with YieldRouter
- [ ] `EmergencyModule.sol` — timelock-gated emergency exit
- [ ] Unit and integration tests — principal lock invariant fuzz testing
- [ ] Testnet deployment

### Milestone 3: Savings Circle (Weeks 13–20)
- [ ] `ISavingsCircle.sol` interface
- [ ] `CircleBuffer.sol` — buffer reserve management
- [ ] `SavingsCircle.sol` — circle lifecycle, round execution
- [ ] Chainlink VRF integration — selection randomness
- [ ] ZK membership circuit (`membership.circom`)
- [ ] `MembershipVerifier.sol`
- [ ] Full circle lifecycle integration test
- [ ] Testnet deployment and multi-week testnet circle run

### Milestone 4: Solidarity Market (Weeks 21–28)
- [ ] `ISolidarityMarket.sol` interface
- [ ] ZK savings history circuit (`savings_history.circom`)
- [ ] `HistoryVerifier.sol`
- [ ] `SolidarityMarket.sol` — vouch creation, income distribution
- [ ] Solidarity Market discovery list (privacy-preserving)
- [ ] End-to-end vouch + circle + selection test
- [ ] Testnet deployment

### Milestone 5: Governance and Security (Weeks 29–36)
- [ ] `CommonsGovernor.sol` — one-member-one-vote governance
- [ ] Governance parameters (fee rate, allocation weights, buffer reserve %)
- [ ] `OndoAdapter.sol` — real-world yield source integration
- [ ] External security audit (all contracts)
- [ ] ZK circuit audit (independent of contract audit)
- [ ] Bug bounty program launch
- [ ] Formal verification of core invariants

### Milestone 6: Frontend (Weeks 20–36, parallel with M4/M5)
- [ ] Wallet connect + privacy wallet support
- [ ] Savings Account dashboard (balance, yield, position breakdown)
- [ ] Circle activation and status view
- [ ] Solidarity Market browse and vouch interface
- [ ] Client-side ZK proof generation (WASM compiled circuits)
- [ ] Mobile-first responsive design
- [ ] Accessibility audit

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
  → Position{balance: 200, obligation: 0} created (shielded)

Member activates circle participation
  → SavingsAccount.activateCircle()
  → BalanceVerifier verifies proof(balance >= minContribution)
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
| Aave V3 | Protocol exploit | Allocation cap: max 60% to any single DeFi source |
| Ondo / real-world yield | Regulatory action | Switchable adapter; protocol can route 100% to DeFi if real-world source is suspended |
| Privacy layer (Aztec) | Technology not production-ready | Fallback plan: Circom + RAILGUN (lower privacy guarantees but deployable) |
| USDC | De-peg or freeze | Protocol governance can add USDT, DAI support within 1 governance cycle |
