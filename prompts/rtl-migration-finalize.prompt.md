---
name: rtl-migration-finalize
description: >
  Final closure workflow for Enzyme → RTL test migration. Verifies all test files
  have been migrated (no Enzyme patterns remain), updates the migration queue if
  work is incomplete, then provides cleanup instructions for migration artifacts.
  Use when: Ready to finalize migration phase, about to create PR, or verifying
  migration completeness before merge.
agent: agent
---

# RTL Migration Finalize: Verify Completeness & Close Migration

You are finalizing the Enzyme → RTL test migration. This workflow:

1. **Verifies completeness** — Scans all changed test files AND support files (setup, helpers, package.json) for remaining Enzyme patterns
2. **Reports status** — Identifies incomplete work and updates the migration queue if needed
3. **Cleans up** — Inventories and removes migration setup artifacts once migration is confirmed complete

**Prerequisites:** All test files should be migrated and passing your project's validation checks.

---

## Step 1: Run Completeness Verification

Scan all modified test files for remaining Enzyme patterns (mount, shallow, wrapper.find):

```bash
# Navigate to your project root
cd <YOUR_PROJECT_ROOT>

# Get list of changed test files from your default branch
# Replace 'origin/dev' with your actual default branch (e.g., origin/main, origin/master)
CHANGED_FILES=$(git diff --name-only origin/dev | grep -E '\.test\.(js|jsx|ts|tsx)$')

echo "Scanning for Enzyme remnants in changed test files..."
echo "======================================================"

INCOMPLETE=()
for file in $CHANGED_FILES; do
  if grep -qE "from\s+['\"]enzyme['\"]|mount\(|shallow\(|wrapper\.|\.setState\(|\.find\(" "$file"; then
    INCOMPLETE+=("$file")
    echo "❌ $file — Enzyme patterns detected"
  else
    echo "✅ $file — Clean"
  fi
done

echo ""
echo "======================================================"
echo "Total files scanned: $(echo "$CHANGED_FILES" | wc -l)"
echo "Incomplete files: ${#INCOMPLETE[@]}"
```

**Note:** Replace `origin/dev` with your repository's default branch (e.g., `origin/main`, `origin/master`).

---

## Step 1b: Scan Support Files for Enzyme Remnants

Test files are not the only place Enzyme lingers. Also scan setup files, helper utilities,
and `package.json` manifests — these are **not** caught by Step 1's test-file filter.

```bash
echo "Scanning support/utility files for Enzyme remnants..."
echo "======================================================"

# setup.jest.js / setup files — Enzyme.configure() calls
grep -rl -E "from\s+['"]enzyme['"]|Enzyme\.configure|enzyme-adapter" \
  --include='setup.jest.js' --include='setup.js' \
  workspaces/ 2>/dev/null | while read f; do
    echo "❌ $f — Enzyme setup found"
done

# Test helper utilities (non-test JS/TS files inside test/ or test-helpers/)
find workspaces -type f \( -name '*.js' -o -name '*.ts' \) \
  \( -path '*/test/helpers/*' -o -path '*/test-helpers/*' \) \
  ! -name '*.test.*' 2>/dev/null | while read f; do
  if grep -qE "from\s+['"]enzyme['"]|mount\(|shallow\(" "$f"; then
    echo "❌ $f — Enzyme patterns detected"
  fi
done

# package.json files — enzyme in dependencies/devDependencies
find workspaces -name 'package.json' ! -path '*/node_modules/*' 2>/dev/null | while read f; do
  if grep -q '"enzyme"' "$f"; then
    echo "❌ $f — enzyme dependency found"
  fi
done

echo "====================================================="
echo "Done. Fix any ❌ items above before proceeding."
```

**Common findings:**
- `setup.jest.js` — remove `import { configure } from 'enzyme'`, `import Adapter`, and `configure({ adapter: new Adapter() })`
- Test helper files (e.g. `intl-enzyme-helper.ts`) — delete if no longer imported anywhere
- `package.json` — remove `enzyme` and `enzyme-adapter-react-*` from `devDependencies`

---

## Step 2: Analyze Results

**If all test files and support files are clean:**
→ Jump to Step 5: Cleanup artifacts

**If test files remain incomplete:**
→ Continue to Step 3: Update migration queue and request completion

**If only support files have Enzyme (setup.jest.js, package.json, helpers):**
→ Fix those directly (remove Enzyme imports/deps), then re-run Step 1b to confirm clean

---

## Step 3: Update Migration Queue (If Incomplete)

If Enzyme patterns were found, update the migration queue with remaining work:

```bash
# Define the path to your migration queue file
# Common locations: .github/instructions/, docs/, or your project docs folder
QUEUE_FILE="<PATH_TO_YOUR_MIGRATION_QUEUE>"
# Example: QUEUE_FILE=".github/instructions/enzyme-to-rtl-migration-queue.md"

# If it doesn't exist, note that migrations were tracked elsewhere
if [ ! -f "$QUEUE_FILE" ]; then
  echo "Note: No migration queue found at $QUEUE_FILE"
  echo "These files still contain Enzyme patterns and need migration:"
  for file in "${INCOMPLETE[@]}"; do
    echo "  - $file"
  done
else
  echo "Updating $QUEUE_FILE with incomplete files..."
  # Append remaining files to the queue with status "In Progress"
  echo "" >> "$QUEUE_FILE"
  echo "## Remaining Work (Re-discovered)" >> "$QUEUE_FILE"
  echo "" >> "$QUEUE_FILE"
  for file in "${INCOMPLETE[@]}"; do
    echo "- [ ] $file" >> "$QUEUE_FILE"
  done
  echo "" >> "$QUEUE_FILE"
  echo "**Last updated:** $(date)" >> "$QUEUE_FILE"
fi
```

**⚠️ USER ACTION REQUIRED:**

Before you can finalize, please:
1. Migrate the remaining files listed above using your RTL migration agent (e.g., `rtl-migrate`)
2. Run your test validation script on each migrated file to ensure all checks pass
3. Re-run Step 1 to confirm all files are clean
4. Once clean, run this prompt again to proceed with cleanup

---

## Step 4 (Skipped - Resume When Complete)

This step is skipped because migration is incomplete. Complete the files listed in
Step 3, then return here.

---

## Step 5: Discover & Inventory rtl-init Artifacts (Migration Complete ✅)

Once all files are migrated and clean, inventory the setup artifacts created during RTL migration initialization:

```bash
# Define your artifacts directory (typically where instructions are stored)
ARTIFACTS_DIR=".github/instructions"  # Adjust path if your project uses a different location

# Migration queue and instruction files
find "$ARTIFACTS_DIR" -maxdepth 1 \
  -name '*enzyme-to-rtl-migration-queue*' \
  -o -name '*enzyme-to-rtl-migration.instructions*' \
  2>/dev/null

# Mock patterns and session plan notes
find "$ARTIFACTS_DIR" -maxdepth 1 \
  -name 'mock-patterns*' \
  -o -name 'rtl-batch*-fix-plan*' \
  -o -name 'not-work-*.instructions*' \
  2>/dev/null
```

**Common artifact paths:**
- `.github/instructions/` — GitHub-based projects
- `docs/` or `docs/migration/` — Docs-centric projects
- `.agents/instructions/` — Projects with dedicated agent directories

---

## Step 6: Categorize Findings

Build an inventory table of artifacts found:

| File | Created By | Purpose | Safe to Remove? |
|------|-----------|---------|-----------------|
| `enzyme-to-rtl-migration-queue.md` | RTL migration init | Tracks migration progress per file | Keep until PR merged; delete after |
| `enzyme-to-rtl-migration.instructions.md` | RTL migration init | Project-specific migration rules | Keep if future migrations planned; delete otherwise |
| `mock-patterns.md` | RTL migration init | Documents mock patterns found in the codebase | Keep for reference or delete |
| `rtl-batch*-fix-plan.md` | Migration session notes | Batch-specific fix plans and notes | Delete when the batch is merged |

For each file found, show its:
- Last-modified date
- File size
- Brief summary of content

This helps you judge whether it still contains useful information.

---

## Step 7: Confirm Scope with User

Present the inventory table from Step 6, then ask:

> "Migration is complete! These are the files written during RTL migration setup and batch sessions.
> Which would you like to remove?
> 
> 1. **Session notes only** — Batch-specific fix plans (safe, already merged)
> 2. **All migration docs** — Queue + instructions + mock patterns + session notes (full cleanup)
> 3. **Custom selection** — Choose specific files individually"

---

## Step 8: Generate Removal Commands

Based on the user's confirmed selection, generate a shell script block.
Use `rm -f` for files. Never use `rm -rf`.

Customize the paths below to match where your artifacts are stored:

```bash
# Define your artifacts directory
ARTIFACTS_DIR=".github/instructions"  # Adjust if different

# Option 1: Session notes only (safe to remove once batch is merged)
rm -f "$ARTIFACTS_DIR"/rtl-batch*-fix-plan.md

# Option 2: Full cleanup (only if no further migrations planned)
rm -f "$ARTIFACTS_DIR"/enzyme-to-rtl-migration-queue.md
rm -f "$ARTIFACTS_DIR"/enzyme-to-rtl-migration.instructions.md
rm -f "$ARTIFACTS_DIR"/mock-patterns.md
rm -f "$ARTIFACTS_DIR"/rtl-batch*-fix-plan.md
rm -f "$ARTIFACTS_DIR"/not-work-*.instructions.md
```

---

## Step 9: Post-Cleanup Verification

After removal, confirm nothing was missed:

```bash
# Define your artifacts directory
ARTIFACTS_DIR=".github/instructions"

# Check if any RTL-related files remain
find "$ARTIFACTS_DIR" -maxdepth 1 \
  \( -name '*enzyme-to-rtl*' \
  -o -name 'mock-patterns*' \
  -o -name 'rtl-batch*' \
  -o -name 'not-work-*' \) \
  2>/dev/null && echo "⚠️  Files remain" || echo "✅ Clean"
```

Report a final summary:
- What was removed
- What was kept (if any)
- Any items that could not be removed (requiring manual intervention)

---

## Step 10: Optional — Remove RTL Skill Infrastructure

If the RTL migration skills, prompts, and agent definitions are no longer needed
(i.e., no more migrations planned for this repo), use the uninstall script from the
RTL toolkit repository instead of removing files manually.

Run from the toolkit repo (the repo that contains `scripts/uninstall-from-project.sh`):

```bash
# Remove installed RTL skills/prompts/agents from your target project
bash scripts/uninstall-from-project.sh --target <YOUR_PROJECT_ROOT>
```

Common variants:

```bash
# Non-interactive removal (auto-confirm)
bash scripts/uninstall-from-project.sh --target <YOUR_PROJECT_ROOT> -y

# Preserve generated instruction/queue files for audit/history
bash scripts/uninstall-from-project.sh --target <YOUR_PROJECT_ROOT> --keep-instructions

# If you installed to custom locations, pass matching paths
bash scripts/uninstall-from-project.sh \
  --target <YOUR_PROJECT_ROOT> \
  --skills-path <CUSTOM_SKILLS_PATH> \
  --prompts-path <CUSTOM_PROMPTS_PATH> \
  --agents-path <CUSTOM_AGENTS_PATH> \
  --instructions-path <CUSTOM_INSTRUCTIONS_PATH>
```

**Keep RTL infrastructure if:**
- You plan additional RTL migrations in this repo
- You want to reuse this setup for other projects
- Your team uses these prompts/agents as ongoing migration tooling

---

## Final Checklist

Before you commit your migration PR, verify:

- [ ] **Step 1:** Ran completeness verification — all files clean
- [ ] **Step 3:** Updated migration queue (if incomplete) or confirmed complete
- [ ] **Step 5-9:** Removed all migration artifacts OR chose to keep specific files
- [ ] **Post-cleanup:** Ran verification that no artifact files remain
- [ ] **All validation passes:**
  - All changed test files pass your validation script (e.g., `verify.sh`, custom linter)
  - No Enzyme imports remain in any test file
  - All tests pass in your test runner (Jest, Vitest, etc.)
- [ ] **Code quality:** ESLint, Prettier, and TypeScript checks pass (where applicable)
- [ ] **Documentation:** Updated any migration progress docs or team notes

**Ready to merge!** Your RTL migration is complete and the workspace is clean.
