#!/bin/bash

# verify.sh
# Usage: ./verify.sh <file-path>
# Runs validation layers for a migrated RTL test file (no LLM steps):
#   Layer 1: ESLint
#   Layer 2: Prettier (auto-fix)
#   Layer 3: Jest
#   Layer 4: TypeScript type check
#   Layer 5: Enzyme remnant grep

set -e

if [[ -z "$1" ]]; then
    echo "Usage: $0 <file-path>"
    echo "Example: $0 src/components/Foo/Foo.test.jsx"
    exit 1
fi

FILE="$1"

if [[ ! -f "$FILE" ]]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

# Resolve absolute path so we can derive the workspace root
ABS_FILE=$(realpath "$FILE")
REPO_ROOT=$(git -C "$(dirname "$ABS_FILE")" rev-parse --show-toplevel 2>/dev/null || dirname "$ABS_FILE")

# Detect workspace dir by walking up to the nearest dir containing package.json
# that is a direct child of workspaces/ (e.g. workspaces/app, workspaces/web)
WORKSPACE_DIR=""
CANDIDATE=$(dirname "$ABS_FILE")
while [[ "$CANDIDATE" != "$REPO_ROOT" && "$CANDIDATE" != "/" ]]; do
    PARENT=$(dirname "$CANDIDATE")
    GRANDPARENT=$(dirname "$PARENT")
    if [[ "$GRANDPARENT" == "$REPO_ROOT" ]] && [[ "$(basename "$PARENT")" == "workspaces" ]]; then
        if [[ -f "$CANDIDATE/package.json" ]]; then
            WORKSPACE_DIR="$CANDIDATE"
            break
        fi
    fi
    CANDIDATE="$PARENT"
done

# Fall back to repo root if no workspace found
if [[ -z "$WORKSPACE_DIR" ]]; then
    WORKSPACE_DIR="$REPO_ROOT"
fi

# Path relative to workspace for Jest
REL_FILE="${ABS_FILE#${WORKSPACE_DIR}/}"

PASS=0
FAIL=0

pass() { echo "  [PASS] $1"; ((PASS++)) || true; }
fail() { echo "  [FAIL] $1"; ((FAIL++)) || true; }

separator() { echo ""; echo "── $1 ──────────────────────────────────"; }

# ── Layer 1: ESLint ───────────────────────────────────────────────────────────
separator "Layer 1: ESLint (auto-fix)"
npx eslint --fix "$ABS_FILE" || true
if npx eslint "$ABS_FILE"; then
    pass "No lint errors"
else
    fail "Lint errors remain after auto-fix — manual intervention needed"
fi

# ── Layer 2: Prettier ─────────────────────────────────────────────────────────
separator "Layer 2: Prettier (auto-fix)"
npx prettier --write "$ABS_FILE"
pass "Formatting applied"

# ── Layer 3: Jest ─────────────────────────────────────────────────────────────
separator "Layer 3: Jest (workspace: $(basename "$WORKSPACE_DIR"))"
if (cd "$WORKSPACE_DIR" && npx jest "$REL_FILE" --passWithNoTests); then
    pass "All tests pass"
else
    fail "Tests failed — see Jest output above"
fi

# ── Layer 4: TypeScript ───────────────────────────────────────────────────────
separator "Layer 4: TypeScript"
if [[ "$ABS_FILE" == *.ts || "$ABS_FILE" == *.tsx ]]; then
    # Resolve tsc: prefer workspace-local, then repo-root, then PATH
    TSC_BIN=""
    if [[ -x "$WORKSPACE_DIR/node_modules/.bin/tsc" ]]; then
        TSC_BIN="$WORKSPACE_DIR/node_modules/.bin/tsc"
    elif [[ -x "$REPO_ROOT/node_modules/.bin/tsc" ]]; then
        TSC_BIN="$REPO_ROOT/node_modules/.bin/tsc"
    elif command -v tsc &>/dev/null; then
        TSC_BIN="tsc"
    fi

    if [[ -z "$TSC_BIN" ]]; then
        echo "  [SKIP] tsc not found in workspace, repo root, or PATH — skipping type check"
    else
        # Run tsc with project config (no file arg) to avoid no-config mode which
        # causes spurious @types duplicate errors. Filter output to the target file only.
        TSC_OUTPUT=$(cd "$WORKSPACE_DIR" && "$TSC_BIN" --noEmit 2>&1 | grep "$REL_FILE" || true)
        if [[ -z "$TSC_OUTPUT" ]]; then
            pass "No type errors"
        else
            echo "$TSC_OUTPUT"
            fail "Type errors found — see tsc output above"
        fi
    fi
else
    echo "  [SKIP] Not a TypeScript file — skipping tsc"
fi

# ── Layer 5: Enzyme remnant check + test name diff ────────────────────────────
separator "Layer 5: Enzyme Remnant Check"

ENZYME_HITS=0

check_pattern() {
    local label="$1"
    local pattern="$2"
    local matches
    matches=$(grep -nE "$pattern" "$ABS_FILE" 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
        echo "  [WARN] $label:"
        echo "$matches" | sed 's/^/    /'
        ((ENZYME_HITS++)) || true
    fi
}

check_pattern "Enzyme import"             "from 'enzyme'"
check_pattern "Enzyme adapter import"     "enzyme-adapter"
check_pattern "enzyme-to-json import"     "enzyme-to-json"
check_pattern "mount/shallow calls"       "\bmount\(|\bshallow\("
check_pattern "wrapper. method calls"     "wrapper\.(find|prop|state|instance|simulate|dive|update|setProps|setState)\("
check_pattern ".simulate( calls"          "\.simulate\("
check_pattern "sinon usage"               "\bsinon\."

if [[ $ENZYME_HITS -eq 0 ]]; then
    pass "No Enzyme remnants found"
else
    fail "$ENZYME_HITS Enzyme pattern(s) found — convert using RTL patterns"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
separator "Summary"
echo "  Passed : $PASS"
echo "  Failed : $FAIL"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo "All layers passed. File is ready to commit."
    exit 0
else
    echo "Fix the failures above before committing."
    exit 1
fi
