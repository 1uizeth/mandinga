# Spec 006 — Automation Layer (Chainlink CRE)

**Status:** Draft
**Version:** 0.1
**Date:** March 2026
**Depends on:** Spec 001 (Savings Account), Spec 002 (Savings Circle), Spec 003 (Safety Net Pool), Spec 004 (Yield Engine)

---

## Changelog

**v0.1 (March 2026):**
- Initial spec. Defines four Chainlink CRE workflow use cases for protocol automation.

---

## Overview

The Automation Layer uses Chainlink CRE (Compute Runtime Environment) to provide decentralised, reliable automation for protocol-critical operations. CRE workflows run on a DON (Decentralised Oracle Network) with cron triggers and on-chain state checks. This replaces reliance on MEV searchers or altruistic callers for liveness.

**Scope:** CRE workflows are included in v1. DON deployment and ACE configuration are part of the v1 release. research.md Decision 8 is superseded by this spec for the Automation Layer.

---

## Clarifications

### Session 2026-03-03

- Q: Quando a camada de automação CRE deve ser implementada e deployada? → A: v1 — Incluir CRE no escopo inicial; DON deploy junto com os contratos
- Q: Quem deve acionar o Safety Net Pool quando um membro precisa de cobertura do gap? → A: Membro — O membro que ativou o mínimo chama; CRE só monitora e alerta
- Q: Quantos rounds de não pagamento antes de iniciar a realocação? → A: 1 — Um round de tolerância antes de realocar
- Q: Qual a frequência do cron para formação automática de círculos? → A: A cada 1 hora
- Q: Quando o workflow deve chamar harvest() no YieldRouter? → A: Cron fixo — harvest() em schedule (ex.: 1x/dia); check de APY só para monitoramento

---

## Four CRE Workflow Use Cases

### 1. Cron Job — Automatic Circle Opening

**Purpose:** Periodically evaluate the matching queue and trigger circle formation when conditions are met.

**Behaviour:**
- Workflow runs on a cron schedule: **every 1 hour** (e.g. `0 * * * *` — top of each hour)
- Queries on-chain queue state grouped by `(depositPerRound, duration)`
- When a group reaches candidate size, invokes the kickoff algorithm
- Calls the formation contract method to create the circle

**Contract interface** (Spec 002 US-006, `contracts/workflow-contracts.md`):
- **Queue**: `getQueuedIntents(depositPerRound, duration)` — returns queued intents grouped by params
- **Formation/Factory**: `formCircle(queueGroupId, selectedN, memberIds)` — creates circle with kickoff result. Backend must implement per Spec 002 AC-006-1 to AC-006-4.

**Open:** Formation threshold integration, gas budget per run. **R-004:** Kickoff roda off-chain no CRE; workflow chama contrato com resultado.

---

### 2. Safety Pool Trigger Verification (Monitor & Alert)

**Purpose:** Monitor when the Safety Net Pool needs to be activated and alert the member. The member who activated the minimum option is responsible for calling the pool contract.

**Behaviour:**
- Workflow checks active circles for members who have activated the minimum option
- For each round boundary, verifies whether `accountBalance < depositPerRound` for any member
- When coverage is needed, CRE emits an alert (off-chain notification, event, or dashboard signal) — it does **not** call the pool contract
- The member calls the Safety Net Pool to cover the gap; CRE only monitors and alerts

**Open:** Alert delivery mechanism (push notification, indexer event, etc.).

---

### 3. Verification and Removal of User from Circle for Non-Payment

**Purpose:** Detect members who cannot pay even `minDepositPerRound` and initiate reallocation (Spec 002 US-008).

**Behaviour:**
- Workflow scans circles for members whose balance is insufficient for `minDepositPerRound` at round boundary
- **Grace period: 1 round** — reallocation is initiated only after the member fails to pay `minDepositPerRound` for one full round (tolerance for transaction delay)
- When detected, initiates reallocation flow: member exits, contributions returned minus Safety Net debt
- Safety Net Pool temporarily covers the open slot while replacement is sought

**Open:** Notification flow, replacement matching cadence. **R-003:** Contrato deve expor `initiateReallocation` chamável pelo CRE após 1 round de falha.

---

### 4. AAVE Yield Percentage Check

**Purpose:** Monitor Aave V3 yield rate and trigger `harvest()` on a fixed schedule. APY check is for monitoring only.

**Behaviour:**
- Workflow runs `harvest()` on YieldRouter on a **fixed cron schedule** (e.g. 1x/day — `0 0 * * *` at midnight UTC)
- Separate workflow or same workflow reads current APY from Aave (or yield router) for monitoring/alerting — no harvest trigger based on threshold
- Circuit breaker (if anomalous conditions detected) may be triggered separately; harvest logic is schedule-driven, not threshold-driven

**Open:** Exact harvest schedule (1x/day default), circuit breaker integration.

---

## Requirements

### Functional Requirements

- **FR-000:** v1 MUST include CRE DON deployment and ACE configuration (supersedes research.md Decision 8 for this layer)
- **FR-001:** System MUST use Chainlink CRE workflows for the four use cases above
- **FR-001a:** Safety Pool trigger: the **member** calls the pool contract; CRE workflow only monitors and alerts when coverage is needed
- **FR-001b:** Non-payment reallocation: 1 round grace period — reallocation is initiated only after the member fails `minDepositPerRound` for one full round
- **FR-001c:** Circle formation cron: workflow runs every 1 hour
- **FR-001d:** Yield harvest: `harvest()` on fixed cron schedule (e.g. 1x/day); APY check for monitoring only, not threshold-triggered
- **FR-002:** Each workflow MUST be independently deployable and configurable
- **FR-003:** Workflows MUST be permissionless in terms of who can trigger — the DON executes them on schedule
- **FR-004:** Workflows MUST handle contract failures gracefully (retry, backoff, alerting)

### Non-Functional Requirements

- **NFR-001:** Workflow execution latency: [NEEDS CLARIFICATION]
- **NFR-002:** Cost per run: [NEEDS CLARIFICATION — gas budget, LINK cost]

---

## Risks & Considerations

*Review 2026-03-03: verificação de problemas nas abordagens aplicadas.*

### R-001 · Safety Pool: dependência do membro como caller

**Problema:** FR-001a exige que o **membro** chame o contrato do pool para cobrir o gap. O membro que ativou a opção mínima está em dificuldade financeira (por isso usa o mínimo). Exigir que ele chame cria risco:
- Pode esquecer de chamar
- Pode estar indisponível (viagem, saúde)
- Pode não ter gas para a transação
- O círculo pode travar se o membro não chamar

**Alternativa considerada:** O `executeRound()` (ou quem o chama) poderia puxar do pool automaticamente ao detectar que o membro pagou `minDepositPerRound` — o membro não precisaria chamar nada. Isso exigiria alteração em Spec 002/003 para definir o fluxo on-chain.

**Status:** Decisão mantida (membro chama). Mitigação: alertas CRE devem ser proativos e claros; frontend deve guiar o membro no fluxo.

---

### R-002 · research.md desatualizado

**Problema:** research.md Decision 8 e RC-006 ainda dizem "No CRE in v1". Spec 006 sobrescreve isso, mas research.md não foi atualizado.

**Ação recomendada:** Atualizar research.md para registrar que Spec 006 inclui CRE em v1 e sobrescreve Decision 8 para esta camada.

---

### R-003 · Fluxo de realocação: interação humana vs CRE

**Problema:** Spec 002 US-008 AC-008-1 diz "the protocol surfaces a question: is there a smaller depositPerRound the member can sustain?" — isso implica interação humana. O CRE não pode "fazer uma pergunta" ao membro. O fluxo exato precisa ser definido: o CRE detecta não-pagamento e chama um método on-chain para iniciar a realocação; a "pergunta" (AC-008-1) pode ser um passo de UX no frontend antes do membro chegar a esse estado, ou o membro pode já ter indicado que não consegue pagar.

**Status:** A definir no plano — garantir que o contrato exponha `initiateReallocation(circleId, memberId)` (ou similar) chamável pelo CRE após 1 round de falha; a UX da "pergunta" fica no frontend.

---

### R-004 · Local do algoritmo de kickoff

**Problema:** Spec 002 US-006 descreve o kickoff (computa N, roundLength, APY, etc.). Não está definido se roda on-chain (gas intensivo) ou off-chain (CRE computa e chama contrato com o resultado).

**Status:** Aberto. Recomendação: kickoff off-chain no CRE; workflow chama `formCircle(queueGroupId, selectedN, memberIds)` com o resultado.

---

## Out of Scope

- Frontend UI for automation status (deferred)
- Cross-chain automation (single-chain v1)

---

## Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| OQ-001 | Cron schedule for circle formation: hourly, every 6 blocks, or configurable per network? | Protocol | **Closed** — Every 1 hour (per Clarifications 2026-03-03) |
| OQ-002 | Safety Pool trigger: who is the authorised caller — CRE workflow or permissionless? | Protocol | **Closed** — Member calls; CRE monitors and alerts (per Clarifications 2026-03-03) |
| OQ-003 | Non-payment grace period: how many rounds before reallocation? | Product | **Closed** — 1 round (per Clarifications 2026-03-03) |
| OQ-004 | AAVE yield check: harvest on schedule vs on-demand when threshold? | Protocol | **Closed** — Cron fixo (ex.: 1x/dia); APY check só para monitoramento (per Clarifications 2026-03-03) |
| OQ-005 | CRE workflow deployment: v1 or v2? (research.md says v2) | Product | **Closed** — v1 (per Clarifications 2026-03-03) |
| OQ-006 | R-001: Reconsiderar abordagem Safety Pool? Membro como caller tem risco de falha; alternativa: executeRound puxa do pool automaticamente. | Product | Open |
