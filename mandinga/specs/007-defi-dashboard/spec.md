# Feature Specification: DeFi Dashboard

**Feature Branch**: `007-defi-dashboard`
**Created**: 2026-03-06
**Status**: Draft
**Depends on**: Spec 001 (Savings Account), Spec 002 (Savings Circle), Spec 004 (Yield Engine)

**Input**: Build a frontend web application to interact with all smart contracts deployed in this project. The app should support wallet connection, Savings Account activation and display, Savings Circles participation view, and Yield Overview.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Wallet Connection (Priority: P1)

A user arrives at the application and must connect their wallet before accessing any protocol features. The application supports multiple wallet providers: Injected Wallet (browser extension), MetaMask, and WalletConnect.

**Why this priority**: Wallet connection is the entry point — no protocol interaction is possible without it.

**Independent Test**: Can be fully tested by visiting the app, attempting to connect, and verifying the connected state is displayed. Delivers value by enabling users to access the protocol.

**Acceptance Scenarios**:

1. **Given** [user visits the app], **When** [user selects Injected Wallet and approves connection], **Then** [wallet address is displayed and connection state persists]
2. **Given** [user visits the app], **When** [user selects MetaMask and approves connection], **Then** [wallet address is displayed and user can access protocol features]
3. **Given** [user visits the app], **When** [user selects WalletConnect and completes QR pairing], **Then** [wallet address is displayed and user can access protocol features]
4. **Given** [user is connected], **When** [user disconnects or switches accounts], **Then** [UI reflects disconnected state and prompts reconnection]

---

### User Story 2 - Savings Account Activation & Display (Priority: P2)

Once connected, a user can activate their Savings Account by making an initial deposit. The app displays the user's total deposited amount (in USDC) and total shares held. On testnet, MockUSDC is used but displayed as USDC in the UI.

**Why this priority**: Savings Account is the foundational position — users must activate it before participating in circles or earning yield.

**Independent Test**: Can be fully tested by connecting, depositing, and verifying the displayed balance and shares are correct. Delivers value by enabling users to hold their savings.

**Acceptance Scenarios**:

1. **Given** [user is connected with no active account], **When** [user deposits USDC (MockUSDC on testnet)], **Then** [Savings Account is activated and user sees balance and shares]
2. **Given** [user has an active Savings Account], **When** [user views the dashboard], **Then** [total deposited amount in USDC is displayed]
3. **Given** [user has an active Savings Account], **When** [user views the dashboard], **Then** [total shares held is displayed]
4. **Given** [user is on testnet], **When** [user views token amounts], **Then** [MockUSDC is displayed as USDC in the UI]

---

### User Story 3 - Savings Circles Participation View (Priority: P3)

A user can view a dedicated section showing all circles they participate in. For each circle, the user sees circle details, current status, and the next round date — i.e., when they can call joinCircle or when the next round executes.

**Why this priority**: Circle participation is essential for users who want to leverage the ROSCA mechanic.

**Independent Test**: Can be fully tested by joining a circle and verifying the circle list, status, and next round date are displayed correctly. Delivers value by enabling users to track their circle commitments.

**Acceptance Scenarios**:

1. **Given** [user participates in one or more circles], **When** [user selects the Savings Circles view], **Then** [all circles the user is in are listed]
2. **Given** [user views a circle], **When** [circle details are displayed], **Then** [circle status (forming, active, completed) is shown]
3. **Given** [user views an active circle], **When** [next round date is relevant], **Then** [the next round date/time is displayed — when joinCircle or round execution is available]
4. **Given** [user is not in any circle], **When** [user selects the Savings Circles view], **Then** [empty state or join flow is shown]

---

### User Story 4 - Yield Overview (Priority: P4)

A user can view their cumulative yield earned since their first deposit, giving them a clear picture of total returns over time.

**Why this priority**: Yield visibility builds trust and helps users understand the value of their participation.

**Independent Test**: Can be fully tested by depositing, waiting for yield accrual, and verifying the displayed cumulative yield is correct. Delivers value by surfacing returns earned.

**Acceptance Scenarios**:

1. **Given** [user has an active Savings Account with deposits], **When** [user views the Yield Overview], **Then** [cumulative yield earned since first deposit is displayed]
2. **Given** [user has no deposits or has earned no yield], **When** [user views the Yield Overview], **Then** [zero or appropriate empty state is shown]
3. **Given** [user has earned yield in multiple circles and standalone account], **When** [user views the Yield Overview], **Then** [total cumulative yield across all sources is displayed]

---

### Edge Cases

- What happens when the user switches networks (e.g., from mainnet to testnet)? The app should detect and prompt or guide the user to the correct network.
- How does the system handle a wallet that disconnects mid-session? The app should gracefully handle disconnection and prompt reconnection.
- What happens when the user has insufficient balance for a deposit? The app should show a clear error and prevent the transaction.
- How does the system handle slow or failed RPC responses? The app should show loading states and retry or error messaging.
- What happens when a circle has no next round (e.g., completed)? The app should display appropriate status or next action.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The application MUST require wallet connection before any protocol interaction.
- **FR-002**: The application MUST support Injected Wallet (browser extension) as a connection provider.
- **FR-003**: The application MUST support MetaMask as a connection provider.
- **FR-004**: The application MUST support WalletConnect as a connection provider.
- **FR-005**: The application MUST allow users to activate their Savings Account by making a deposit.
- **FR-006**: The application MUST display the user's total deposited amount in USDC (or equivalent).
- **FR-007**: The application MUST display the user's total shares held in the Savings Account.
- **FR-008**: On testnet, the application MUST use MockUSDC but display it as USDC in the UI.
- **FR-009**: The application MUST provide a dedicated view for Savings Circles showing all circles the user participates in.
- **FR-010**: For each circle, the application MUST display circle details and current status.
- **FR-011**: For each circle, the application MUST display the next round date when joinCircle or round execution is available.
- **FR-012**: The application MUST display the user's cumulative yield earned since their first deposit.
- **FR-013**: The application MUST read all displayed data from the deployed smart contracts.

### Key Entities

- **User**: A wallet holder who connects and interacts with the protocol. Identified by wallet address.
- **Savings Account**: A yield-bearing position holding deposited USDC and shares. Has attributes: total deposited (USDC), shares balance.
- **Savings Circle**: A ROSCA group the user participates in. Has attributes: circle ID, status (forming/active/completed), next round date, member count, contribution per member.
- **Yield**: Cumulative returns earned since first deposit. Derived from share price appreciation and circle payouts.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can connect their wallet within 30 seconds using any supported provider.
- **SC-002**: Users can complete Savings Account activation (deposit) in under 2 minutes.
- **SC-003**: Users can see their balance, shares, and circle participation status within 2 seconds of page load.
- **SC-004**: Users can view their cumulative yield earned at a glance without additional clicks.
- **SC-005**: 90% of users successfully complete primary flows (connect, deposit, view circles) on first attempt without support.

## Assumptions

- The deployed smart contracts (SavingsAccount, SavingsCircle, YieldRouter, etc.) are deployed and accessible on the target network.
- MockUSDC is available on testnet for deposit flows.
- Wallet providers (MetaMask, WalletConnect) are available and functional in the user's environment.
- The network (Base Sepolia testnet or mainnet) is specified in the deployment configuration.
- Yield is derived from on-chain state (share price appreciation).
