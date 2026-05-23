---
name: initialize-project
description: Gather library versions, migration status counts, and helper paths for an actionable migration snapshot. Used as the /init command for the enzyme-to-rtl-migration skill.
triggers:
  - "/init"
  - "init migration"
  - "project overview"
  - "migration status"
  - "what needs to be migrated"
---

# Initialize: Enzyme → RTL Migration Project Overview

Use this instruction when the user runs `/init` or asks for a migration project overview.
Gather **only** enzyme-to-RTL migration relevant facts. Do not explore application
runtime code, business logic, React routes, proxy servers, or unrelated infrastructure.

---

## Purpose

Produce a focused, actionable snapshot of the migration state so that subsequent
migration sessions start with full context and no repeated discovery work.

Primary mechanism: use the local collector bash script if available for fast, accurate
data collection. Fall back to manual steps only if the script is unavailable or returns
incomplete results.

Primary outputs:
1. Library versions (Enzyme, RTL, React, Jest, adapter).
2. Migration status counts (not migrated / mixed / partially migrated / complete).
3. Project-specific helpers and providers required for RTL rendering.
4. Risk-ordered file list ready for the migration workflow.

---

## Scope

**Gather only:**
- `package.json` files for dependency versions.
- Test files (`**/*.test.js`, `**/*.test.ts`, `**/*.test.jsx`, `**/*.test.tsx`,
  `**/*.spec.*`) for Enzyme / RTL usage patterns.
- Existing custom render helpers (e.g. `renderWithRedux`, `renderWithIntl`,
  `renderWithRouter`, `test-helpers/`).
- Jest config files for global setup, `setupFilesAfterEnv`, transform rules,
  and test segmentation behavior.
- Enzyme adapter config/setup files.
- Test-execution pipeline facts directly related to migration work: package scripts,
  Jest CI/reporter settings, timezone test handling, workspace/package boundaries,
  and test report output paths.

**Ignore entirely:**
- Application source code outside test files.
- React route definitions, legacy page HTML, proxy/server code.
- CI/CD and packaging details unrelated to test execution or migration batching.
- Build config details not needed to understand how tests execute.
- Business logic, API integrations, styling, i18n message catalogs.

---

## Workflow

### Step 0: Try the Collector Script (Primary Path)

Check if the local bash script is available and executable:

```bash
bash ./collect-init-overview.sh --mode preview
```

**If the script runs successfully:**
- Use the `--mode preview` output as the concise overview.
- Ask whether to run `--mode full` for the complete report.
- Skip Steps 1–5 below; use the script output directly.

**If the script fails or is not available:**
- Proceed to **Step 1** and use the manual workflow below.
- (Manual steps are included for offline/backup scenarios.)

### Step 1: Version Discovery (Manual Fallback)

Read root and workspace-level `package.json` files. Extract versions for: `enzyme`, `enzyme-adapter-react-*`, `@testing-library/react`, `@testing-library/user-event`, `@testing-library/jest-dom`, `react`/`react-dom`, `jest`, `@types/enzyme`. Report as a version table. Flag if both `enzyme` and `@testing-library/react` exist (mixed-state project).

### Step 2: Migration Status Scan (Manual Fallback)

Count test files into four categories — **enzyme-only** (Enzyme import, no RTL), **mixed** (both), **rtl-incomplete** (RTL only + `it.skip`/`it.todo`/`TODO`), **rtl-complete** (RTL only, clean). Report counts per category plus total. Do **not** read or summarize application logic inside those files.

### Step 3: Custom Render Helpers Discovery (Manual Fallback)

Search common locations (`test-helpers/`, `__mocks__/`, `src/test-utils/`, `testUtils/`) for files that import `@testing-library/react`. Report each helper's name, file path, and which providers it wraps (Redux, Router, Intl, Theme, etc.) so migration steps can reuse the correct import paths.

### Step 4: Enzyme Adapter Setup + RTL `testIdAttribute` (Manual Fallback)

Search setup files (`setup.jest.*`, `setupTests.*`, `jest.setup.*`) for the Enzyme adapter import. Report which adapter is used, where it is configured, and whether `shallow` or only `mount` appears in test files (affects migration complexity).

**Also collect the RTL `testIdAttribute`** — this determines which HTML attribute
`getByTestId` / `queryByTestId` / `getAllByTestId` resolve at runtime.

Search setup files (`setup.jest.*`, `setupTests.*`, `jest.setup.*`) for a
`configure({ testIdAttribute: '...' })` call from `@testing-library/react`.
If absent, the default is `data-testid`.

> **This value is critical.** Every mock stub, every element the test queries by test-id,
> and every instruction file section on selectors must use the discovered attribute.
> Record it prominently in the project instruction file and never assume `data-testid`.

### Step 5: Risk-Ordered File List (Manual Fallback)

Tier every enzyme-only and mixed file by complexity — **Low** (< 100 lines and < 5 tests), **Medium** (100–300 lines or 5–15 tests), **High** (> 300 lines or > 15 tests). List all files (no cap), sorted low → high within each tier. Include line count, test count, and status per entry.

#### Persist as Migration Queue File

Write the sorted list as a Markdown checkbox file to:
```
.github/instructions/enzyme-to-rtl-migration-queue.md
```

**If the file already exists:** merge — preserve checked-off entries (`- [x]`), append new files, remove completed ones, re-sort unchecked entries by line count. Report path written, total files, and how many were already checked off.

> **Migration sessions should start here.** When the user asks "what should I migrate
> next?", point them to the first unchecked entry in the Low Risk section of
> `.github/instructions/enzyme-to-rtl-migration-queue.md`.

### Step 6: Verify or Bootstrap Project Instruction File

Check whether a project-specific instruction file exists at:

```
.github/instructions/enzyme-to-rtl-migration.instructions.md
```

**If it exists:** read it and confirm the helper import paths, `intl` prop guidance,
and selector helpers match what was found in Step 3. Report any gaps.

**If it does not exist:** create it using the facts gathered in Steps 1–3.
The file must cover at minimum:

1. **Import replacements** — which Enzyme helpers to remove and which project RTL helpers
   to add (with correct import paths from Step 3).
2. **Render helper selection table** — mapping each Enzyme mount pattern to the
   appropriate project helper (`render`, `renderWithRedux`, `renderWithReduxAndRouter`,
   `renderWithRouter`, etc.).
3. **`intl` prop in `defaultProps`** — whether to drop it or replace it with
   `createMockedIntl()` (based on whether the project uses `injectIntl` or direct prop).
4. **Legacy selector helpers** — `queryById`, `queryByQa`, `queryByClassName`,
   `getAllByAttribute` (or equivalent project helpers found in Step 3).
5. **`wrapper` variable removal** discipline — explicitly state that no `wrapper.`
   reference may remain after migration.
6. **Validation command** — the path to `verify.sh` (or the project's equivalent).
7. **`testIdAttribute`** (from Step 4) — explicitly state the configured value and the
   rule derived from it, e.g.:
   - If `data-qa`: _"Use `data-qa` on all DOM elements and mock stubs; never `data-testid`."_
   - If `data-testid` (or not set): _"Use `data-testid` (RTL default)."_
   This must appear prominently so no migration step silently falls back to the wrong attribute.
8. **Mock patterns** — placeholder section to be filled in by Step 7 below.

Set the file's `applyTo` frontmatter to match the test file glob for this workspace
(e.g. `workspaces/**/*.test.{js,jsx,ts,tsx}`).

Report:
- Whether the file existed or was created.
- Any discrepancies corrected between the file and the live project facts.

### Step 7: Mock Pattern Analysis

After completing Steps 1–6, offer the user mock pattern analysis with a message such as:

> "I can scan the test files to categorize the mock patterns in use, document them,
> and recommend the best patterns to standardize on going forward.
> Once we align on the patterns, I'll add them to your project instruction file.
> Would you like me to do that?"

When the user accepts, scan a representative sample of existing test files, categorize
the mock patterns in use, and produce:

1. A documented list of patterns found — each with a name, description, and a
   representative code example drawn directly from the test suite.
2. A **recommendation** of which patterns to standardize on going forward, with a
   one-line rationale for each choice and any patterns that should be replaced.

After presenting items 1 and 2, **pause and check in** before writing anything:

> "Here's what I found and my recommendations. Do you have any adjustments —
> patterns to add, remove, or rename? Let's finalize the list before I update
> the instruction file."

Incorporate the user's feedback, then proceed to step 3 once the content is agreed on.

3. Write the agreed patterns into a `## Mock Patterns` section in
   `.github/instructions/enzyme-to-rtl-migration.instructions.md`, including:
   - Patterns to use (name, description, minimal example).
   - Patterns to avoid, with the preferred replacement.
   - Any project-specific rules (e.g., which attribute to use on stubs, preferred
     render helpers, etc.).

If the `## Mock Patterns` section already exists in the instruction file, diff it
against the findings and update any stale entries.

### Step 8: Generate Project-Specific Lint-Fix Script

Gather the exact ESLint and Prettier flags the project uses in CI, then write a
customized `lint-fix.sh` to `.github/instructions/lint-fix.sh`.

**Do not read** files inside `.agents/skills/` or `.github/skills/` — those are
skill-level defaults. Read only project-owned sources:

#### 8a — Gather ESLint flags

1. Read `.github/workflows/lintcheck-branch.yml` and extract the `yarn eslint ...`
   command. Key flags to capture:
   - `-c <config-path>` — explicit config file (e.g. `.eslintrc.js`)
   - `--no-eslintrc` — disables config file auto-discovery
   - `--no-error-on-unmatched-pattern` — silences no-match errors
   - Any additional `--rule` or `--ext` overrides
2. Confirm the config file referenced by `-c` exists at the repo root
   (e.g. `.eslintrc.js`). Note its path relative to the repo root.
3. Check `bin/run-local-tests.sh` for any extra flags not present in the workflow.

#### 8b — Gather Prettier flags

1. Read `.github/workflows/prettiercheck-branch.yml` and extract the
   `yarn prettier ...` command. Note that the workflow uses `-c` (check mode);
   the generated script will use `--write` instead.
2. Check whether `.prettierrc`, `.prettierrc.json`, `.prettierrc.js`, or
   `prettier.config.js` exists at the repo root. If a config file exists, no
   extra formatting flags are needed — Prettier reads it automatically.
3. If no config file exists, record every explicit flag from the workflow command
   (e.g. `--single-quote`, `--trailing-comma`, `--tab-width`) to embed in the script.

#### 8c — Write `.github/instructions/lint-fix.sh`

Using the gathered values, write the script with:
- The exact ESLint flags from CI (with `--fix` added for auto-fix mode).
- `npx prettier --write "$FILE"` — no extra flags when a `.prettierrc` config file
  exists; embed explicit flags only if no config file was found.
- A header comment citing each source file the flags were read from.

**Template** (fill in `<eslint-config-path>` and the prettier flags section):

```bash
#!/bin/bash
# lint-fix.sh — Project-specific auto-fix script
# ESLint flags sourced from: .github/workflows/lintcheck-branch.yml
# Prettier flags sourced from: .github/workflows/prettiercheck-branch.yml + <.prettierrc path or "none">
# Usage: ./lint-fix.sh <file-path>

set -e

if [[ -z "$1" ]]; then
    echo "Usage: $0 <file-path>"
    exit 1
fi

FILE="$1"
[[ -f "$FILE" ]] || { echo "Error: File not found: $FILE"; exit 1; }

# ESLint — flags match lintcheck-branch.yml (auto-fix mode)
npx eslint -c <eslint-config-path> --no-eslintrc --fix --no-error-on-unmatched-pattern "$FILE" 2>/dev/null || true

# Prettier — respects <.prettierrc path> (matches prettiercheck-branch.yml config)
# If no project config file: npx prettier --write <flags from workflow> "$FILE"
npx prettier --write "$FILE" 2>/dev/null

echo "✓ Formatted: $FILE"
```

**If `.github/instructions/lint-fix.sh` already exists**, diff it against the
gathered flags and update only lines that diverge from the current CI commands.
Report which flags changed and why.

After writing the file, make it executable:
```bash
chmod +x .github/instructions/lint-fix.sh
```

Report:
- Source files read (workflows, scripts, config files).
- ESLint flags captured and their source.
- Prettier flags captured and their source (config file or explicit flags).
- Path written: `.github/instructions/lint-fix.sh`
- Whether the file was created or updated.

---

## Analysis Summary (Manual Fallback Only)

If using the manual workflow (script unavailable), present a concise preview before
generating the full output:

- Total test files scanned
- Enzyme-only / mixed / rtl-incomplete / rtl-complete counts
- Versions of key libraries
- Custom render helpers found (yes/no, count)

Ask whether to proceed with:
1. Full overview (all sections)
2. Status counts + versions only
3. Risk-ordered file list only

---

## Output Structure

```
## Migration Project Overview

### Library Versions
<version table>

### Migration Status
<status counts table>
Total: X files | Remaining work: Y files

### Custom Render Helpers
<list of helpers + file paths + providers>

### Enzyme Adapter Setup
<adapter name, config location, shallow/mount usage>

### RTL `testIdAttribute`
<configured value — e.g. `data-qa` or `data-testid` (default)>
<rule: which HTML attribute to use on elements and mock stubs>

### Project Instruction File
<existed | created> — .github/instructions/enzyme-to-rtl-migration.instructions.md
<any gaps or corrections noted>

### Lint-Fix Script
<created | updated> — .github/instructions/lint-fix.sh
ESLint flags: <flags captured from lintcheck-branch.yml>
Prettier: <"uses .prettierrc" | explicit flags captured>

### Mock Patterns
<mock pattern analysis pending — prompt the user with the Step 7 recommendation>

### Risk-Ordered File List
#### Low Risk (< 100 lines, < 5 tests)
- path/to/file.test.js

#### Medium Risk
- ...

#### High Risk (> 300 lines or > 15 tests)
- ...

→ Full list written to `.github/instructions/enzyme-to-rtl-migration-queue.md`
  (checkbox format, sorted low → high, ready for the migration workflow)

### Assumptions / Gaps
<anything not determinable from static analysis>
```

---

## What to Ignore in Output

Do **not** include in the overview:
- Component tree descriptions or business logic summaries.
- Route maps, flow diagrams, API dependencies.
- Webpack, Babel, or build tooling notes unless they directly control test execution.
- Deployment, release, or unrelated CI/CD pipeline details.
- Legacy page or HTML template references.
- Any content unrelated to the test migration itself.
