# Tasks: DeFi Dashboard

**Input**: Design documents from `mandinga/specs/007-defi-dashboard/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Organization**: Tasks em arquivos separados por phase. Cada story é independentemente testável.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Pode rodar em paralelo (arquivos diferentes, sem dependências)
- **[Story]**: Label da user story (US1, US2, US3, US4)
- Incluir caminhos exatos nas descrições

## Path Conventions

- **Webapp**: `webapp/` na raiz do repo
- **Components**: `webapp/src/components/{atoms,molecules,organisms,templates}/`
- **Hooks**: `webapp/src/hooks/`
- **Pages**: `webapp/src/app/`

---

## Phase Files

| Phase | File | Description |
|-------|------|--------------|
| 1 | [task-01-setup.md](./task-01-setup.md) | Project initialization |
| 2 | [task-02-foundational.md](./task-02-foundational.md) | Layout, theme, wagmi (bloqueia todas as stories) |
| 3 | [task-03-wallet-connection.md](./task-03-wallet-connection.md) | US1 — Wallet Connection (MVP) |
| 4 | [task-04-savings-account.md](./task-04-savings-account.md) | US2 — Savings Account |
| 5 | [task-05-circles-view.md](./task-05-circles-view.md) | US3 — Circles View |
| 6 | [task-06-yield-overview.md](./task-06-yield-overview.md) | US4 — Yield Overview |
| 7 | [task-07-polish.md](./task-07-polish.md) | Polish & cross-cutting |

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: Sem dependências — iniciar imediatamente
- **Phase 2 (Foundational)**: Depende da Phase 1 — **BLOQUEIA** todas as user stories
- **Phases 3–6 (User Stories)**: Todas dependem da Phase 2
  - US1 pode começar primeiro (MVP)
  - US2 depende de US1 (wallet gate)
  - US3 depende de US1 (wallet para membership)
  - US4 depende de US2 (dados da position)
- **Phase 7 (Polish)**: Após as user stories desejadas

### Parallel Opportunities

- Phase 1: T002–T006 em paralelo
- Phase 2: T009, T010, T012, T013, T015 em paralelo
- Tasks marcadas [P] dentro de cada phase

---

## Implementation Strategy

### MVP First (US1 only)

1. Phase 1: Setup
2. Phase 2: Foundational
3. Phase 3: User Story 1 (Wallet Connection)
4. **STOP and VALIDATE**
5. Deploy/demo

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 → Deploy (MVP)
3. Add US2 → Deploy
4. Add US3 → Deploy
5. Add US4 → Deploy
6. Polish → Final deploy
