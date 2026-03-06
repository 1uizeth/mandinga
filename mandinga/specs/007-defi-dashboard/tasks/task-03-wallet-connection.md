# Phase 3: User Story 1 — Wallet Connection (Priority: P1) 🎯 MVP

**Goal**: User can connect wallet via Injected, MetaMask, or WalletConnect; see address; disconnect

**Provider**: `@rainbow-me/rainbowkit@2` — ConnectButton, RainbowKitProvider, getDefaultConfig

**Independent Test**: Visit app → Connect → See address → Disconnect → See prompt

---

- [x] T016 [P] [US1] Create WalletConnectButton molecule in webapp/src/components/molecules/WalletConnectButton.tsx (wraps RainbowKit ConnectButton)
- [x] T017 [US1] Integrate WalletConnectButton into AppHeader in webapp/src/components/organisms/AppHeader.tsx
- [x] T018 [US1] Create wallet gate: show connect prompt when disconnected, hide protocol UI in webapp/src/app/page.tsx
- [x] T019 [US1] Add network mismatch handling (prompt switch to Base Sepolia) in webapp/src/components/molecules/WalletConnectButton.tsx or hooks
- [x] T020 [US1] Display truncated address and disconnect option when connected in webapp/src/components/molecules/WalletConnectButton.tsx

**Checkpoint**: User Story 1 complete — wallet connect/disconnect works independently
