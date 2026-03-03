# Tasks: 001 — Savings Account

**Input**: Design documents from `mandinga/specs/001-savings-account/`
**Prerequisites**: spec.md (required), tasks/ (individual task files)

**Path convention**: Foundry sources at `contracts/` (repo root), not `backend/contracts/`.

---

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4, US5)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Project Initialization)

**Purpose**: Foundry project initialization with OpenZeppelin and Chainlink dependencies

- [ ] T000 Create Foundry project with `contracts/` as src, install OpenZeppelin and Chainlink — see `tasks/task-00-foundry-setup.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Interface and core infrastructure that MUST be complete before implementation

**⚠️ CRITICAL**: Depends on Spec 004 (Yield Engine — IYieldRouter). Task 001-01 can define the interface in parallel with yield engine work.

- [ ] T001 [P] Define ISavingsAccount interface in `contracts/interfaces/ISavingsAccount.sol` — see `task-01-savings-account-interface.md`

---

## Phase 3: User Story 1–4 — Core Savings Account (P1–P4) 🎯 MVP

**Goal**: Deposit, withdraw, view position, enforce principal lock

**Independent Test**: `forge test --match-path "test/unit/SavingsAccount.t.sol"` — deposit, withdraw, obligation checks pass

### Implementation

- [ ] T002 Implement SavingsAccount contract in `contracts/core/SavingsAccount.sol` — see `task-02-savings-account-contract.md`
- [ ] T003 Add unit tests in `test/unit/SavingsAccount.t.sol`
- [ ] T004 Add invariant tests in `test/invariant/BalanceInvariants.t.sol`

**Checkpoint**: SavingsAccount compiles, tests pass, principal lock invariant enforced

---

## Phase 4: User Story 5 — Emergency Exit (P5)

**Goal**: Time-locked emergency withdrawal path for protocol emergencies

**Independent Test**: `forge test --match-path "test/unit/EmergencyModule.t.sol"` — timelock, propose, execute, cancel

### Implementation

- [ ] T005 [P] [US5] Implement EmergencyModule in `contracts/core/EmergencyModule.sol` — see `task-03-emergency-module.md`
- [ ] T006 [US5] Add unit tests in `test/unit/EmergencyModule.t.sol`

**Checkpoint**: Emergency exit path audited and tested independently

---

## Phase 5: Polish & Cross-Cutting

- [ ] T007 [P] Update CLAUDE.md / docs if project structure changed
- [ ] T008 Run full test suite: `forge test`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on T000 (Foundry setup); T001 also blocked on Task 004-01 (IYieldRouter) for full integration
- **Core (Phase 3)**: Depends on T001 (interface) + Spec 004 (Yield Engine deployed)
- **Emergency (Phase 4)**: Depends on T001; can run in parallel with T002 once interface exists
- **Polish (Phase 5)**: Depends on all above

### Task → File Mapping

| Task | File |
|------|------|
| T000 | task-00-foundry-setup.md |
| T001 | task-01-savings-account-interface.md |
| T002 | task-02-savings-account-contract.md |
| T003 | task-02 (tests) |
| T004 | task-02 (invariant) |
| T005 | task-03-emergency-module.md |
| T006 | task-03 (tests) |

---

## Implementation Strategy

### MVP First (Core Savings Only)

1. T000 → T001 → T002 → T003 → T004
2. **STOP and VALIDATE**: `forge test` passes
3. Deploy/demo SavingsAccount

### Incremental Delivery

1. Setup + Foundational → interface ready
2. Add SavingsAccount → test independently
3. Add EmergencyModule → test independently
4. Polish → full suite

---

## Notes

- All contract paths use `contracts/` at repo root (not `backend/contracts/`)
- `bytes32 shieldedId` throughout; v1 uses `keccak256(abi.encodePacked(msg.sender, nonce))`
- Invariant: `sharesBalance >= circleObligationShares` at all times
