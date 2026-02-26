# cre-manding-circle — Analysis & Spec Mapping

**Repo:** [luanpontolio/cre-manding-circle](https://github.com/luanpontolio/cre-manding-circle)
**Date analysed:** February 2026
**Purpose:** Identify what can be directly reused, what needs adaptation, and what must be built from scratch for Mandinga Protocol.

---

## Summary

This is production-quality Solidity code with Chainlink VRF v2.5 already integrated, a Foundry test suite, and a Chainlink CRE automation workflow skeleton. It covers the circle mechanics layer of our spec in substantial depth. It does not touch the savings account, yield engine, solidarity market, or privacy layer at all.

**Bottom line:** roughly 40% of what we need to build for the `SavingsCircle` primitive already exists here. The VRF draw consumer can be used as-is. The vault and factory need adaptation, not replacement. The three missing layers (yield, solidarity market, privacy) are greenfield.

---

## Contract-by-Contract Mapping

### DrawConsumer.sol → **Direct reuse** ✅

This is exactly what Task 004-02 (VRF integration) in Spec 002 calls for.

- Uses Chainlink VRF v2.5 via Direct Funding wrapper (`VRFV2PlusWrapperConsumerBase`) — the correct modern version
- Fisher-Yates shuffle on VRF callback produces a fully randomised participant ordering — every selection is verifiable on-chain
- Clean separation: `DrawConsumer` is owned by the vault, one instance per circle
- `drawCompleted(requestId)` and `getDrawOrder(requestId)` interfaces are exactly what `SavingsCircle.sol` needs to call

**No changes needed.** Drop this directly into our contracts/core/. The only thing to verify: the VRF v2.5 Direct Funding wrapper address for the networks we deploy on (Base Sepolia for testnet, confirmed in the code comments).

---

### CircleFactory.sol → **Reuse with light adaptation** ✅⚡

The factory pattern is right. Per-circle deployment of vault + share token + NFT + draw consumer is correct architecture.

Already branded: `ERC20Claim("Mandinga Claim", "MCLM")` and `PositionNFT("Mandinga Position", "MPOS")` — Luan already had the name.

**What to adapt:**
- Add `YieldRouter` address as a constructor parameter, passed through to each vault
- Add `SolidarityMarket` address for future vouching integration
- The `circleId` hash (via `CircleIdLib`) is a good pattern — keep it, but note it exposes circle parameters publicly. In the privacy version, the circleId should be an opaque commitment.

---

### CircleVault.sol → **Reuse core structure, adapt mechanics** ⚡

This is the most important contract to understand. It implements the ROSCA loop well, but with different mechanics than our spec in a few critical places.

**What maps directly:**
- Circle lifecycle states: `ACTIVE / FROZEN / SETTLED / CLOSED` → align with our `FORMING / ACTIVE / COMPLETED / EMERGENCY`
- Installment tracking via `PositionNFT` — good pattern
- `requestCloseWindow()` → permissionless trigger, anyone can call — exactly what we want
- `redeem()` → winner pulls the full pot — this is the payout mechanic
- `exitEarly()` with fee → maps to our grace period exit, though our mechanics differ (see below)
- `canCloseWindow()` with sequential ordering across windows — elegant enforcement

**Where the mechanics differ from our spec — decisions needed:**

**1. Quota window system (EARLY / MIDDLE / LATE)**

The vault divides the circle into three time-based cohorts with capped slots each. Members choose their cohort at enrolment. This is *not* capital-based bidding — it's preference expression by timing — so it does not violate the consórcio anti-pattern.

This is actually a stronger implementation of what Spec 002 US-004 AC-004-4 describes as "preference expression." Rather than pure random, members can choose when in the cycle they'd *prefer* to be eligible, without purchasing the right to be selected. Selection within each cohort is still VRF-random.

**Recommendation: adopt this pattern.** It's fairer than pure VRF and gives members meaningful agency without replicating the auction mechanic. Update Spec 002 to formalise it.

**2. Payout mechanics**

Current design: winner calls `redeem()`, receives USDC directly to their wallet, their own share tokens (ERC20Claim) are burned.

Our spec design: payout is deposited into the winner's SavingsAccount as a principal lock (circle obligation), not withdrawable.

**These are incompatible as-is.** To bridge them: the `redeem()` function needs to call `SavingsAccount.creditPrincipal(shieldedId, potAmount)` and set the obligation, rather than transferring USDC directly to the winner. The USDC stays in the protocol earning yield.

**3. Principal lock / pause mechanic**

The current repo has no pause mechanic. A member who can't pay installments can `exitEarly()` with a fee. Our spec requires a pause/grace period rather than a penalised exit.

**Recommendation:** Add `pauseMember()` / `resumeMember()` functions to the vault alongside the existing `exitEarly()`. Early exit with fee is actually a useful complement to pause/resume — keep both.

**4. No yield**

The vault holds USDC idle. The entire yield engine is missing. This is the most significant gap.

---

### PositionNFT.sol → **Reuse as-is** ✅

Clean ERC721 with a `PositionData` struct tracking:
- `quotaId` (which phase cohort)
- `targetValue`, `totalInstallments`, `paidInstallments`, `totalPaid`
- `Status`: ACTIVE / EXITED / FROZEN / CLOSED

Maps well to our member slot tracking. The NFT approach also makes positions visible (for the member's own wallet) without revealing balances — a reasonable privacy trade-off for v1.

**No changes needed for v1.** In the privacy version, the NFT would need to be issued to a shielded address rather than the raw member address.

---

### ERC20Claim.sol → **Reuse as-is** ✅

The share token mechanic is smart:
- Members accumulate claim tokens as they pay installments
- Transfer freeze during the snapshot/draw window prevents gaming
- `burn()` on redemption or early exit clears the position cleanly

This is a neat solution to the "how do we track proportional eligibility" problem. Keep it.

---

### CircleErrors.sol → **Reuse as-is** ✅

Complete, gas-efficient custom error library. Already covers the main failure modes. We'll extend it with errors for:
- `PrincipalLockViolation`
- `MemberPaused`
- `InsufficientYield`
- `VouchNotActive`

---

### workflow/multichain/main.ts → **Expand significantly** ⚡

This is a Chainlink CRE (Compute Runtime Environment) workflow — Chainlink's decentralised automation layer. Currently it's a Hello World cron stub, but the skeleton is exactly what we need.

**This solves the keeper problem.** In our plan.md we noted that `executeRound()` is "permissionless — any address can trigger it" but didn't specify who actually calls it. The answer is: a CRE workflow.

A CRE workflow on a cron schedule can:
1. Check `canCloseWindow(quotaId, roundIndex)` for all active circles
2. Call `requestCloseWindow()` on any eligible windows
3. Call `harvest()` on the YieldRouter on a separate schedule
4. Check for paused members and call `checkAndPause()` where needed

This is a much more reliable liveness mechanism than depending on MEV searchers or altruistic callers.

**Recommendation:** This workflow is a first-class component of Mandinga Protocol, not an optional add-on. Add it as Spec 006 — Automation Layer.

---

## Toolchain Observations

**The repo uses Foundry, not Hardhat.** Our plan.md specified Hardhat/TypeScript. We should switch.

Foundry advantages for this project:
- Faster test execution (Rust-based)
- `vm.warp()` for time manipulation — essential for circle lifecycle tests
- `vm.prank()` for address impersonation
- Fuzz testing built-in (`forge test --fuzz-runs`)
- The existing test suite already uses these — `test_GetCurrentPhase`, `test_CanCloseWindow_AfterDeadline` etc. are well-written Foundry tests

**Update plan.md:** Replace Hardhat/TypeScript with Foundry/Solidity for all contract tests. Keep TypeScript only for the CRE workflow (which requires it by the CRE SDK).

---

## What Needs to Be Built from Scratch

These are entirely absent from the repo and must be built greenfield:

| Component | Spec | Notes |
|---|---|---|
| `SavingsAccount.sol` | Spec 001 | Foundation — build first |
| `YieldRouter.sol` | Spec 004 | Routes idle USDC to Aave/Ondo |
| `AaveAdapter.sol` | Spec 004 | Aave V3 yield source |
| `OndoAdapter.sol` | Spec 004 | Real-world yield source |
| `OracleAggregator.sol` | Spec 004 | Chainlink rate feeds |
| `SolidarityMarket.sol` | Spec 003 | Vouching market |
| `EmergencyModule.sol` | Spec 001 | Timelock emergency exit |
| ZK circuits | Spec 005 | Balance range proofs |
| `MandigaGovernor.sol` | plan.md | One-member-one-vote governance |
| CRE workflow (expanded) | New Spec 006 | Keeper automation |
| Frontend | plan.md | Mobile-first PWA |

---

## Recommended Plan Updates

### 1. Switch to Foundry
Replace all Hardhat references in `plan.md` with Foundry. Existing tests in `cre-manding-circle/contracts/test/` can be imported directly.

### 2. Adopt the quota window system in Spec 002
The EARLY/MIDDLE/LATE cohort design is a genuine improvement over pure VRF — it gives members preference agency without capital-based selection. Update Spec 002 US-004 to formalise this.

### 3. Integrate yield into CircleVault
The payout flow in `CircleVault.redeem()` needs to route through `SavingsAccount` rather than transferring USDC directly to the winner. The USDC stays in the protocol. The winner receives the yield on the full pot amount, not the pot itself.

### 4. Add Spec 006 — Automation Layer
The CRE workflow is a first-class protocol component. It needs its own spec covering: round execution triggers, yield harvest scheduling, pause detection, and failure handling.

### 5. Add pause/resume to CircleVault
Alongside the existing `exitEarly()`, add `pauseMember()` and `resumeMember()` to handle temporary contribution shortfalls without penalising members who can recover.

### 6. Keep CircleErrors.sol and extend it
It's clean and complete. Add Mandinga-specific errors rather than replacing it.

---

## Build Sequence Update (Revised)

```
Phase 0 (Architecture): Privacy layer decision + Foundry setup
Phase 1 (Yield):        YieldRouter → AaveAdapter → OracleAggregator (greenfield)
Phase 2 (Savings):      SavingsAccount → EmergencyModule (greenfield)
Phase 3 (Circle):       Adapt CircleVault + integrate YieldRouter + SavingsAccount
                        DrawConsumer and CircleFactory: minimal changes needed
Phase 4 (Solidarity):   SolidarityMarket (greenfield)
Phase 5 (Automation):   Expand CRE workflow (extend existing skeleton)
Phase 6 (Governance):   MandigaGovernor + parameter controls
Phase 7 (Privacy):      ZK circuits + verifiers (depends on Phase 0 decision)
Phase 8 (Frontend):     Mobile-first PWA
```
