# Task 001-00 — Foundry Project Setup

**Spec:** 001 — Savings Account
**Milestone:** 0 (Setup)
**Status:** Ready
**Estimated effort:** 1–2 hours
**Dependencies:** None
**Parallel-safe:** No — foundational setup

---

## Objective

Initialize the Foundry project at repository root with `contracts/` as the Solidity source directory (not `backend/contracts`). Install OpenZeppelin Contracts and Chainlink dependencies.

---

## Context

The Mandinga protocol uses Foundry for Solidity development. `foundry.toml` and `contracts/` are placed at the **repo root** (`/mandinga`), alongside `script/`, `test/`, and `lib/`. Chainlink (VRF v2.5) is required by Spec 002 (SavingsCircle); installed here as a shared dependency. Spec 001 itself does not use Chainlink directly.

See: CLAUDE.md (Active Technologies).

---

## Acceptance Criteria

- [ ] `forge init --no-commit` run at repo root, then:
  - Rename generated `src/` to `contracts/` (or skip generation and create `contracts/` manually)
  - Edit `foundry.toml` to set `src = "contracts"`
- [ ] `foundry.toml` at repo root configured as:
  ```toml
  [profile.default]
  src = "contracts"
  out = "out"
  test = "test"
  script = "script"
  solc = "0.8.20"
  fs_permissions = [{ access = "read", path = "lib/foundry-chainlink-toolkit/out" }]
  ```
- [ ] `forge install foundry-rs/forge-std --no-commit`
- [ ] OpenZeppelin installed (single command — brings both `contracts` and `contracts-upgradeable` from same release):
  ```bash
  forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit
  forge install OpenZeppelin/openzeppelin-foundry-upgrades --no-commit
  ```
- [ ] Chainlink installed:
  ```bash
  forge install smartcontractkit/foundry-chainlink-toolkit --no-commit
  ```
- [ ] `remappings.txt` at repo root contains:
  ```
  @openzeppelin/contracts/=lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/
  @openzeppelin/contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/
  @chainlink/contracts/=lib/foundry-chainlink-toolkit/lib/chainlink/contracts/
  forge-std/=lib/forge-std/src/
  ```
- [ ] Directory structure created under `contracts/`:
  - `contracts/core/`
  - `contracts/yield/`
  - `contracts/interfaces/`
  - `contracts/governance/` — criar vazio com `.gitkeep`; reservado para v2 (MandigaGovernor + TimelockController)
- [ ] `forge build` succeeds with empty contract set

---

## Output Files

- `foundry.toml` (repo root)
- `remappings.txt` (repo root)
- `contracts/core/`, `contracts/yield/`, `contracts/interfaces/`
- `contracts/governance/.gitkeep` (placeholder — contratos de governança são v2)
- `script/`
- `test/unit/`, `test/integration/`, `test/invariant/`
- `lib/forge-std/`
- `lib/openzeppelin-contracts-upgradeable/`
- `lib/openzeppelin-foundry-upgrades/`
- `lib/foundry-chainlink-toolkit/`

---

## Notes

- `openzeppelin-contracts-upgradeable` inclui `openzeppelin-contracts` como submodule interno — **não instalar** `OpenZeppelin/openzeppelin-contracts` separadamente. Isso garante que ambos os remappings (`@openzeppelin/contracts/` e `@openzeppelin/contracts-upgradeable/`) apontem para a mesma release, necessário para verificação no Etherscan.
- `foundry-chainlink-toolkit` é o pacote oficial para Foundry (Chainlink docs). Remapping usa o caminho interno `lib/foundry-chainlink-toolkit/lib/chainlink/contracts/` — verificar após instalação e ajustar se diferir.
- Chainlink é instalado agora como dependência transversal; Spec 001 não o usa, mas Spec 002 (VRF v2.5) e Spec 006 (CRE) dependem dele.
- `fs_permissions` em `foundry.toml` é necessário para que o Foundry Chainlink Toolkit leia seus arquivos de output durante testes.
- Usar `--no-commit` em todos os `forge install`; commitar dependências em etapa separada após validar `forge build`.
- **`contracts/governance/` não tem contratos em v1.** Em v1, parâmetros "governance-configurable" (fee rate, formation threshold) são gerenciados via `Ownable`/`AccessControl` apontando para a multi-sig (3-of-5 Gnosis Safe) — sem contrato de governança dedicado. `MandigaGovernor` e `TimelockController` são v2, ativados quando `OracleAggregator` e multi-adapter entrarem.
