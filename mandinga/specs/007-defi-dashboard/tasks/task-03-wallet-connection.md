# Phase 3: User Story 1 — Wallet Connection (Priority: P1) 🎯 MVP

**Goal**: User can connect wallet via Injected, MetaMask, or WalletConnect; see address; disconnect

**Independent Test**: Visit app → Connect → See address → Disconnect → See prompt

---

- [ ] T016 [P] [US1] Create WalletConnectButton molecule in webapp/src/components/molecules/WalletConnectButton.tsx
- [ ] T017 [US1] Integrate WalletConnectButton into AppHeader in webapp/src/components/organisms/AppHeader.tsx
- [ ] T018 [US1] Create wallet gate: show connect prompt when disconnected, hide protocol UI in webapp/src/app/page.tsx
- [ ] T019 [US1] Add network mismatch handling (prompt switch to Base Sepolia) in webapp/src/components/molecules/WalletConnectButton.tsx or hooks
- [ ] T020 [US1] Display truncated address and disconnect option when connected in webapp/src/components/molecules/WalletConnectButton.tsx

**Checkpoint**: User Story 1 complete — wallet connect/disconnect works independently
