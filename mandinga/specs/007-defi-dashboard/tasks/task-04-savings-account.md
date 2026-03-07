# Phase 4: User Story 2 — Savings Account Activation & Display (Priority: P2)

**Goal**: User can deposit to activate account; see balance (USDC) and shares

**Independent Test**: Connect → Deposit → See balance and shares displayed

---

- [X] T021 [P] [US2] Create useShieldedId hook in webapp/src/hooks/useShieldedId.ts
- [X] T022 [P] [US2] Create useSavingsPosition hook (position, balance, shares) in webapp/src/hooks/useSavingsPosition.ts
- [X] T023 [P] [US2] Create TokenAmountDisplay molecule in webapp/src/components/molecules/TokenAmountDisplay.tsx
- [X] T024 [P] [US2] Create StatCard molecule in webapp/src/components/molecules/StatCard.tsx
- [X] T025 [US2] Create SavingsPositionCard organism in webapp/src/components/organisms/SavingsPositionCard.tsx
- [X] T026 [US2] Create useDeposit hook (approve + deposit) in webapp/src/hooks/useDeposit.ts
- [X] T027 [US2] Add deposit form and action to SavingsPositionCard in webapp/src/components/organisms/SavingsPositionCard.tsx
- [X] T028 [US2] Create Savings Account page/dashboard view in webapp/src/app/dashboard/page.tsx
- [X] T029 [US2] Display MockUSDC as "USDC" in UI (TokenAmountDisplay, labels) in webapp/src/components/molecules/TokenAmountDisplay.tsx
- [X] T030 [US2] Handle zero balance and inactive account empty state in webapp/src/components/organisms/SavingsPositionCard.tsx

**Checkpoint**: User Story 2 complete — deposit and balance display work independently
