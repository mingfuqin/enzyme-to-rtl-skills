# enzyme-to-rtl-skills

An open-source collection of AI agent skills and prompt files for automating the migration of Jest tests from Enzyme to React Testing Library (RTL) using **VS Code with GitHub Copilot Agent Mode**.

The skills encode validated migration patterns, a structured 5-phase workflow, and a 5-layer validation process — all surfaced as slash commands directly in Copilot Chat.

# Quick Start

Run the install script from this repo, pointing it at your project:

```bash
bash scripts/install-to-project.sh --target ../your-project
```

By default this creates **symlinks**, so any updates to this repo are reflected immediately. Use `--copy` for a standalone installation.

```
Options:
  --target <dir>            Target project root (default: cwd)
  --skills-path <path>      Where to put skill files  (default: .github/skills)
  --prompts-path <path>     Where to put prompt files (default: .github/prompts)
  --copy                    Copy files instead of symlinking
  -y, --yes                 Skip confirmation prompts
```

> **Custom paths**: if you use `--skills-path` or `--instructions-path` with non-default values, you must also pass `--copy`. Path-patching (sed) only works on real file copies, not symlinks pointing back to this repo.

# What gets installed

| Destination | Source | What it does |
|---|---|---|
| `.github/prompts/*.prompt.md` | `prompts/` | VS Code slash commands |
| `.github/prompts/enzyme-to-rtl-validate.agent.md` | `prompts/` | Dedicated read-only validation agent mode |
| `.github/skills/enzyme-to-rtl-migration/` | `skills/enzyme-to-rtl-migration/` | Migration skill + shell scripts |
| `.github/skills/enzyme-to-rtl-migration-validation/` | `skills/enzyme-to-rtl-migration-validation/` | Validation skill |
| `.github/instructions/` | _(created empty)_ | Where `/init` writes the queue and instruction files |

> **How VS Code discovers these files**: Prompt files (`.prompt.md`, `.agent.md`) in `.github/prompts/` are auto-discovered by VS Code and become slash commands. Skill files (`SKILL.md`) are **not** auto-loaded — the prompt files reference them explicitly by path. The install script keeps these paths consistent.

# Slash commands

After installation, open Copilot Chat in your project:

| Command | What it does |
|---|---|
| `/enzyme-to-rtl-init` | Scan the project: library versions, migration status, risk-ordered file queue. Run this first. |
| `/enzyme-to-rtl-migrate <file>` | Migrate a single Enzyme test file through the full 5-phase workflow (assess → convert → validate). |
| `/enzyme-to-rtl-migrate-batch` | Migrate files in risk-ordered batches of 3–5, using the queue from `/init`. |
| `/enzyme-to-rtl-validate <file>` | Run all 5 validation layers on a migrated file and report findings (read-only). |
| `/enzyme-to-rtl-validate-batch` | Validate all test files changed on this branch vs the default branch. |

# Recommended workflow

```
1. /enzyme-to-rtl-init
   → Generates .github/instructions/enzyme-to-rtl-migration-queue.md
     and .github/instructions/enzyme-to-rtl-migration.instructions.md

2. /enzyme-to-rtl-migrate-batch
   → Works through the queue low → medium → high risk,
     running inline validation (Phase 5) after each file

3. /enzyme-to-rtl-validate-batch   (optional, before PR)
   → Full 5-layer check on all branch-changed test files
     or switch to the enzyme-to-rtl-validate agent mode for interactive validation
```

# Available skills

| Skill | File | Purpose |
|---|---|---|
| `enzyme-to-rtl-migration` | `skills/enzyme-to-rtl-migration/SKILL.md` | 5-phase migration workflow: assess → convert → validate. Includes selector decision tree, 9 conversion patterns, and inline Phase 5 validation. |
| `enzyme-to-rtl-migration-validation` | `skills/enzyme-to-rtl-migration-validation/SKILL.md` | Deep 5-layer validation (lint, format, jest, types, Enzyme remnants + assertion-quality gate). Used by the `/validate` prompts and the dedicated agent mode. |

# Requirements

- **VS Code** with the **GitHub Copilot** extension (Agent Mode enabled)
- A host project using **Jest** as the test runner

> **Tested with**: React 16, `@testing-library/react` 11, `@testing-library/user-event` 12, Jest 26.
