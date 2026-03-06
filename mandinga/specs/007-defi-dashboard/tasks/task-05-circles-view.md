# Phase 5: User Story 3 — Savings Circles Participation View (Priority: P3)

**Goal**: User sees all circles they participate in; circle details, status, next round date

**Independent Test**: Join circle → Navigate to Circles view → See list with status and next round

---

- [x] T031 [P] [US3] Create useUserCircles hook (circles user participates in) in webapp/src/hooks/useUserCircles.ts
- [x] T032 [P] [US3] Create CircleStatusBadge atom (Ended/Active/Joined variants) in webapp/src/components/atoms/CircleStatusBadge.tsx
- [x] T033 [US3] Create CircleStatusPanel organism in webapp/src/components/organisms/CircleStatusPanel.tsx
- [x] T034 [US3] Create Circles page with list of user circles in webapp/src/app/circles/page.tsx
- [x] T035 [US3] Add filters (Sort by, Status) per v0 reference in webapp/src/app/circles/page.tsx
- [x] T036 [US3] Display next round date for each circle in webapp/src/components/organisms/CircleStatusPanel.tsx
- [x] T037 [US3] Add empty state when user is in no circles in webapp/src/app/circles/page.tsx
- [x] T038 [US3] Style status badges: Ended=gray, Active=green, Joined=blue in webapp/src/components/atoms/CircleStatusBadge.tsx

**Checkpoint**: User Story 3 complete — circles view works independently
