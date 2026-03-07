# Phase 6: User Story 4 — Yield Overview (Priority: P4)

**Goal**: User sees cumulative yield earned since first deposit

**Independent Test**: Deposit → Wait for yield → See cumulative yield displayed

**Implementation note:** Yield is derived from share price appreciation, not from `position.yieldEarnedTotal`. The YieldRouter does not call `creditYield()` on harvest. The `useCumulativeYield` hook computes `(position.balance * savingsAccountValue / totalPrincipal) - position.balance` using `totalPrincipal`, `balanceOf(SA)`, and `convertToAssets(shares)` from the contracts.

---

- [x] T039 [P] [US4] Create useCumulativeYield hook in webapp/src/hooks/useCumulativeYield.ts
- [x] T040 [US4] Create YieldOverview organism/card in webapp/src/components/organisms/YieldOverview.tsx
- [x] T041 [US4] Add YieldOverview to dashboard in webapp/src/app/dashboard/page.tsx
- [x] T042 [US4] Handle zero yield empty state in webapp/src/components/organisms/YieldOverview.tsx
- [x] T043 [US4] Display yield at a glance (no extra clicks) in webapp/src/components/organisms/YieldOverview.tsx

**Checkpoint**: User Story 4 complete — yield overview works independently
