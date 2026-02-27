# Mandinga Protocol — Constitution

> The architectural DNA of Mandinga Protocol. Every specification, plan, and task must align with these principles. When in doubt, return to this document.
>
> **Last updated:** February 2026 — §2.3 revised: privacy layer deferred to v2. See decision rationale in §2.3.

---

## 1. What We Are Building

Mandinga Protocol is a **solidarity savings primitive** — a self-custodial protocol that gives anyone on Earth access to the compounding advantage of lump-sum capital, without a bank account, without KYC, and without surrendering custody of funds.

It encodes the logic of the rotating savings and credit association (ROSCA) — the most widely used community savings mechanism in human history — into immutable, permissionless smart contracts on Ethereum.

**Mandinga Protocol is not:**
- A stablecoin
- A yield aggregator
- A lending protocol
- A credit product dressed as savings

**Mandinga Protocol is:**
- A solidarity savings primitive
- Infrastructure for cooperative financial access
- A mechanism where community IS the collateral

---

## 2. The Core Principles

Principles §2.1, §2.2, §2.4, and §2.5 are non-negotiable and cannot be relaxed, traded off, or deferred. §2.3 has been revised to a roadmap commitment (see rationale below).

### 2.1 No Organiser — Ever

The catastrophic failure mode of traditional ROSCAs is the organiser as single point of trust and control. Mandinga Protocol must eliminate this failure mode entirely.

**Implication:** No human actor, multi-sig, or DAO vote may control the rotation order, hold the pool, or have discretion over any member's principal. All rotation logic, pool custody, and enforcement must be in the smart contract layer.

### 2.2 Structural Enforcement, Not Surveillance

The protocol enforces correct behaviour through incentive design and contract mechanics, not through identity tracking, reputation scoring, or credit bureau interaction.

**Implication:** The principal lock mechanism — where a member's savings balance must always meet or exceed their outstanding circle obligation — is the enforcement layer. There is no default risk because there is no unsecured obligation. Enforcement is in the architecture, not in surveillance.

### 2.3 Privacy as a Roadmap Commitment (deferred to v2)

**Decision (February 2026):** The privacy layer is deferred to v2. v1 deploys without on-chain balance or membership shielding. Member balances and circle participation are visible on the public ledger in v1.

**Rationale:** ZK circuit toolchains (Circom, Noir) and FHE-enabled execution environments (fhEVM, CoFHE) are not yet sufficiently mature for the complexity required by this protocol's mechanics. Premature commitment to a specific privacy stack increases implementation cost, audit surface, and deployment risk without delivering user value in the near term.

**What is preserved for the v2 migration path:**
- All contracts use `bytes32 shieldedId` (derived as `keccak256(abi.encodePacked(msg.sender, nonce))`) rather than raw `address` in state and interfaces. This allows a future migration to commitment-based identity without breaking changes.
- The `shieldedId` abstraction provides pseudonymity at v1 — an observer cannot trivially link on-chain positions to identities without the nonce.
- No feature may be designed that structurally prevents the addition of a privacy layer in v2.

**v2 target:** Once a production-grade privacy execution environment is available and auditable, balance shielding and membership shielding will be added. The `shieldedId` abstraction is the primary migration hook.

### 2.4 Self-Custody at All Times

Users maintain custody of their funds at all times. The protocol holds principal in trust during circle participation — this trust is enforced by code, not by a custodian. Users can always verify the cryptographic guarantee of their principal's safety.

**Implication:** No upgradeable proxy may control user funds without an exit mechanism. No admin key may pause withdrawals. Emergency exit paths are mandatory for all fund-holding contracts.

### 2.5 Governance With Limits on Financial Influence

Participation rights and governance weight are not proportional to deposit size. The cooperative surplus flows to all members, not to the largest holders.

**Implication:** Governance over protocol parameters uses one-member-one-vote mechanics, not token-weighted voting. Yield routing decisions may use delegation but not plutocratic weighting. Protocol fee extraction for large depositors is explicitly prohibited.

---

## 3. The Core Primitives (Build Order)

The protocol is composed of four primitives that must be built in dependency order:

```
1. SavingsAccount     → The foundation. Self-custodial yield-bearing position.
2. YieldEngine        → Routes deposits to real-world yield sources.
3. SavingsCircle      → The ROSCA mechanic built on top of SavingsAccount.
4. SolidarityMarket   → Vouching market built on top of SavingsCircle.
```

**Never build higher primitives before their dependencies are correct.** The SavingsCircle cannot be built correctly without a correct SavingsAccount. The SolidarityMarket cannot be built without a correct SavingsCircle.

---

## 4. Data Model Invariants

These invariants must hold at all times. Any state transition that violates them is a bug.

### SavingsAccount Invariants
- `account.balance >= account.circleObligation` at all times
- If `account.balance < account.circleObligation`, circle participation is `PAUSED`, not terminated
- Yield accrues continuously on the full `account.balance`, including the locked portion
- The locked portion (circle obligation) cannot be withdrawn; the yield it generates can be accessed

### SavingsCircle Invariants
- Every member receives the full pool payout exactly once per full rotation cycle
- The pool payout is deposited into the recipient's `SavingsAccount`, not their withdrawable wallet
- The principal of the payout is `circleObligation`; only the yield differential is the "prize"
- No member may bid for earlier selection in ways that purchase timing advantage with capital (no auction mechanic that replicates consórcio lance logic)
- Verifiable on-chain randomness (e.g., Chainlink VRF) is the default selection mechanism
- A circle never fails due to a single member's inability to contribute; the position pauses

### SolidarityMarket Invariants
- A vouch is economically real: the vouched portion of the voucher's balance is locked for the vouch duration
- The voucher cannot withdraw the vouched portion while the vouch is active
- If the vouched member's position pauses, the vouch obligation also pauses (not defaults)
- No vouch may be for more than 80% of the voucher's balance (diversification floor)
- The voucher earns: (a) interest on the leveraged amount paid from vouched member's yield, and (b) a share of the payout differential when the vouched member is selected

---

## 5. What We Are Explicitly Not Building (Consórcio Anti-Patterns)

The Brazilian consórcio is the cautionary tale. These patterns must never appear in Mandinga Protocol:

| Anti-Pattern | Why It's Forbidden |
|---|---|
| Auction-based early selection (lance) | Allows capital to purchase timing advantage, replicating wealth inequality |
| Lance embutido (embedded bid using credit) | Creates opaque calculation and hidden cost to member |
| Secondary market for circle positions (ágio) | Transforms savings product into speculative credit market |
| Administration fee independent of timing | Misaligns incentives between protocol and members |
| Any mechanism that benefits sophisticated actors over ordinary ones | Violates the solidarity principle |

---

## 6. Technology Stack Principles

### Smart Contracts
- Language: Solidity ^0.8.20
- Framework: Foundry (forge) — no Hardhat
- Network: Ethereum mainnet + L2s (Arbitrum, Base, Optimism) for gas efficiency
- Privacy: Deferred to v2 (see §2.3). v1 uses `shieldedId` pseudonymity only.
- Randomness: Chainlink VRF or equivalent verifiable on-chain randomness for selection
- Yield: Integration with established, audited yield sources only (Aave, Compound, tokenised money market funds with KYC-gated access abstracted at protocol layer)
- Oracles: Chainlink for real-world rate data; designed to continue if any single source fails

### Audits & Safety
- All contracts must be audited before mainnet deployment
- Formal verification of core invariants (SavingsAccount balance invariant, principal lock) is required
- Bug bounty program mandatory before any material TVL accumulates

### Frontend
- Mobile-first interface (primary users are mobile-only)
- Progressive web app or React Native
- No KYC or account creation required at the interface layer
- Dollar-stable asset entry via bridging partners (no speculative asset exposure at onboarding)

---

## 7. Success Metrics

The success of Mandinga Protocol is **not** measured by:
- TVL (total value locked)
- APY offered
- Token price

The success of Mandinga Protocol **is** measured by:
- Number of people who accessed lump-sum capital earlier than they could have alone
- Number of circles that completed without failure
- Geographic and economic breadth of participation
- Degree to which the protocol remains a savings primitive (not captured into a credit product)

---

## 8. The Defipunk Test

Before shipping any feature, ask: **could this exist without Ethereum?**

- If yes: the feature is unnecessary complexity. Simplify.
- If no: the feature is justified. The constraint that makes it only possible on Ethereum is a feature, not a limitation.

Mandinga Protocol passes the Defipunk test on its core mechanics:
- Trustless principal lock without custodian → requires smart contract enforcement
- Verifiable randomness for fair selection → requires on-chain VRF
- Solidarity market vouching with trustless lock → requires smart contract enforcement
- Global, borderless, 24/7 operation without organiser → requires decentralised infrastructure
- Privacy-first balance shielding → deferred to v2; will require ZK or FHE infrastructure when implemented
