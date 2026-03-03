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

The Mandinga protocol uses Foundry for Solidity development. The project structure places contracts at `contracts/` (repo root), with `script/` and `test/` alongside. This task establishes the base for all subsequent contract work (Spec 001, 002, 003, 004).

See: CLAUDE.md (Active Technologies), plan structure.

---

## Acceptance Criteria

- [ ] Foundry project initialized at repo root: `forge init` (or equivalent) with `src = "contracts"` in `foundry.toml`
- [ ] `foundry.toml` configured:
  - `src = "contracts"`
  - `out = "out"`
  - `test = "test"`
  - `script = "script"`
  - Solidity version `^0.8.20` (per CLAUDE.md)
- [ ] OpenZeppelin Contracts v5 installed: `forge install OpenZeppelin/openzeppelin-contracts --no-commit`
- [ ] Chainlink contracts installed: `forge install smartcontractkit/chainlink --no-commit` (or `foundry-chainlink` if applicable)
- [ ] `remappings.txt` (or foundry.toml remappings) includes:
  - `@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/`
  - `@chainlink/contracts/=lib/chainlink/contracts/` (or equivalent path)
- [ ] Directory structure created under `contracts/`:
  - `contracts/core/`
  - `contracts/yield/`
  - `contracts/governance/`
  - `contracts/interfaces/`
- [ ] `forge build` succeeds with no contracts (empty structure compiles)
- [ ] `script/` and `test/` directories exist at repo root (or as configured in foundry.toml)

---

## Output Files

- `foundry.toml` (at repo root)
- `remappings.txt` (or remappings in foundry.toml)
- `contracts/` (directory structure)
- `script/`
- `test/`
- `lib/openzeppelin-contracts/`
- `lib/chainlink/` (or equivalent)

---

## Notes

- Use `--no-commit` on `forge install` to avoid automatic git commits; commit dependencies in a separate step.
- If the repo uses a monorepo layout (e.g. `mandinga/` as subfolder), ensure `foundry.toml` and `contracts/` are placed according to the chosen root (repo root vs. `mandinga/`).
- Chainlink: For VRF and automation, the typical package is `smartcontractkit/chainlink` or `smartcontractkit/foundry-chainlink`. Adjust remappings to match the installed package structure.
- OpenZeppelin v5: Use `@openzeppelin/contracts-upgradeable` if upgradeable proxies are needed later (Spec 004).
