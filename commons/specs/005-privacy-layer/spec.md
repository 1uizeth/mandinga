# Spec 005 — Privacy Layer

**Status:** Draft
**Version:** 0.1
**Date:** February 2026
**Depends on:** Spec 001 (Savings Account)

---

## Overview

The Privacy Layer is the cryptographic infrastructure that ensures member balances, contribution history, and circle membership are shielded from the public ledger. The public chain sees only cryptographic proofs of valid participation — not who is saving, how much, or with whom.

Privacy is not a feature in Commons Protocol. It is a constitutional requirement. Without it, the protocol cannot serve its intended users: people in jurisdictions with financial surveillance, people who cannot safely expose their savings to public observation, and communities whose social fabric depends on the discretion that makes traditional ROSCAs work.

---

## Problem Statement

Public blockchains expose every transaction permanently and irreversibly. For a savings protocol serving people in emerging markets, diaspora communities, and financially marginalised populations, full public exposure would:

1. Make the protocol unusable in jurisdictions where financial activity is monitored and penalised
2. Expose members to targeted theft or coercion based on visible savings balances
3. Destroy the social grace that makes cooperative savings work — traditional ROSCAs function partly because members don't see each other's exact balances
4. Create a permanent, exploitable data trail that defeats the self-custodial value proposition

---

## User Stories

### US-001 · Shielded Balance
**As a** member,
**I want** my savings balance to be invisible to anyone who is not me,
**So that** I am not exposed to surveillance, coercion, or targeted theft.

**Acceptance Criteria:**
- AC-001-1: A member's exact balance is not visible on the public ledger at any time
- AC-001-2: Only the member (via their private key) can decrypt and view their own exact balance
- AC-001-3: Protocol contracts can verify balance sufficiency (e.g., `balance >= circleObligation`) without revealing the exact balance — this requires a ZK proof of balance range
- AC-001-4: No third party — including the protocol operators — can view a member's balance without their private key
- AC-001-5: The shielding mechanism is cryptographic and does not rely on trust in any party

### US-002 · Shielded Circle Membership
**As a** circle member,
**I want** my participation in any circle to be invisible to outside observers,
**So that** my savings circle relationships cannot be used against me.

**Acceptance Criteria:**
- AC-002-1: Circle membership is not publicly linkable to member identities or addresses
- AC-002-2: A circle can be identified by its public circle ID (an opaque hash), but the members of the circle are not publicly associated with it
- AC-002-3: Selection events are visible on-chain (a payout occurred) but not linkable to the recipient's identity or address
- AC-002-4: The circle size and pool amount may be visible (for protocol integrity verification) but member count and member addresses are not
- AC-002-5: A member can prove their own participation in a circle (for support/dispute purposes) via a ZK membership proof, without revealing this to the public chain

### US-003 · Shielded Contribution History
**As a** member,
**I want** my deposit and withdrawal history to be invisible to outside observers,
**So that** my savings behaviour cannot be tracked, profiled, or used against me.

**Acceptance Criteria:**
- AC-003-1: Deposit transactions are shielded: the amount and sender are not visible on the public chain
- AC-003-2: Withdrawal transactions are shielded: the amount and recipient are not visible
- AC-003-3: An observer can verify that the total shielded pool is solvent (the protocol holds at least as much as the sum of all shielded positions) without being able to determine any individual balance
- AC-003-4: Historical transaction data is not stored in a recoverable form outside the member's own encrypted position
- AC-003-5: The protocol does not maintain a centralised off-chain database of member balances or history

### US-004 · ZK Proof of Valid Participation
**As a** protocol enforcing circle mechanics,
**I need to** verify that a member meets participation requirements (balance threshold, obligation coverage) without exposing their balance,
**So that** enforcement can happen on-chain without privacy violation.

**Acceptance Criteria:**
- AC-004-1: A member can generate a ZK proof that their balance meets a specified threshold, without revealing the exact balance
- AC-004-2: This proof is used by the SavingsCircle contract to verify eligibility for circle entry without knowing the member's balance
- AC-004-3: The proof generation is performed client-side (in the member's wallet or browser) — no trusted party is involved in proof generation
- AC-004-4: Proofs are efficient enough to be verified within a single Ethereum transaction (gas target: < 200k gas for proof verification)
- AC-004-5: The ZK circuit for balance proofs is audited independently of the broader contract audit

### US-005 · Savings History for Vouching (Privacy-Preserving)
**As a** potential voucher browsing the Solidarity Market,
**I want to** see a vouched member's savings behaviour (consistency, duration) without seeing their exact balance,
**So that** I can make informed vouching decisions without compromising the vouched member's privacy.

**Acceptance Criteria:**
- AC-005-1: The protocol supports a ZK proof of savings history: a member can generate a proof that they have maintained a savings balance above a certain threshold for at least N months, without revealing the exact amount
- AC-005-2: This proof is shown on the Solidarity Market as a trust signal (e.g., "3+ months consistent savings, balance in the $100–$500 range")
- AC-005-3: The vouched member controls whether to share this proof — it is opt-in, not automatic
- AC-005-4: No exact balance or transaction history is ever revealed in the vouching context
- AC-005-5: The proof is freshness-bound (it must be regenerated at least monthly) to ensure it reflects current behaviour

---

## Privacy Layer Technology Candidates

The following are being evaluated. The final decision must be made before implementation of any other spec, as it affects how all state is stored.

| Option | Pros | Cons | Status |
|---|---|---|---|
| **Aztec Protocol** | Native privacy L2 with mature ZK tooling; designed for exactly this use case | Still maturing; L2 adds latency; cross-L2 composability is complex | Under evaluation |
| **zkSync + private state** | L2 already at scale; growing privacy primitives | Private state is not yet mature in production | Under evaluation |
| **Custom ZK circuits (Circom/Noir)** | Maximum control; can be deployed on any L2 | Highest engineering cost; highest audit surface | Under evaluation |
| **RAILGUN** | Privacy shield for ERC-20 tokens; production-deployed | Not designed for savings circle mechanics; adapting it may introduce complexity | Under evaluation |

**Decision needed before Spec 001 implementation begins.**

---

## Out of Scope for This Spec

- Compliance/regulatory interface (how the protocol handles lawful requests for information — this is a separate legal and governance question, not a protocol design question)
- KYC at any layer (excluded by the constitution)
- Anonymity set expansion (making privacy stronger over time — future work)

---

## Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-001 | Which privacy technology do we build on? This is the highest-priority architectural decision in the project. | Protocol Architect | Urgent / Open |
| OQ-002 | Can we achieve the gas target of < 200k for proof verification on Ethereum L2? This determines whether we can run the full protocol on-chain or need an off-chain proof aggregation layer. | ZK Engineer | Open |
| OQ-003 | How do we handle the transition from transparent deposits (stablecoin transfer in) to shielded savings position? This entry point may leak information about the depositor. | Protocol Architect | Open |
| OQ-004 | Regulatory posture: some jurisdictions require travel rule compliance for crypto transfers above certain thresholds. Does the privacy layer create a legal risk? | Legal | Open |
