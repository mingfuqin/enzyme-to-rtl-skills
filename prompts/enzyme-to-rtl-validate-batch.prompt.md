---
name: enzyme-to-rtl-validate-batch
description: Discover test files changed on this branch vs the default branch, then run all 5 validation layers on each and report findings as a summary table
---

# Enzyme-to-RTL Batch Validation

## Step 1: Discover changed test files

Detect the default branch and find all test files changed on this branch:

```bash
BASE_BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
BASE_BRANCH=${BASE_BRANCH:-main}
git diff "origin/$BASE_BRANCH" --name-only | grep -E '\.test\.(js|jsx|ts|tsx)$'
```

If `git remote show origin` is unavailable or slow, fall back to asking the user:
> "What is your base branch? (e.g. main, master, dev)"

If the result is empty, tell the user no changed test files were found and stop.
Otherwise, use that list as the set of files to validate.

## Step 2: Load project instruction file

Load `.github/instructions/enzyme-to-rtl-migration.instructions.md` if present; apply its rules across all files.

## Step 3: Per-file validation

For each file, apply the same 6 validation layers defined in `enzyme-to-rtl-validate.prompt.md` (Lint, Format, Jest, Types, Enzyme remnants, Assertion quality). Do not apply any fixes.

## Summary report

Return a table showing every file from Step 1 — **do not apply any fixes**.

| File | L1 Lint | L2 Format | L3 Jest | L4 Types | L5 Remnants | L5.5 Quality | Overall |
|------|---------|-----------|---------|----------|-------------|--------------|---------|

Followed by a **Findings** section listing every ❌ with:
- File, layer, line number, and exact error or match
- Recommended fix (which of the 9 Validated Conversion Patterns applies, or the specific command to run)
- Which skill to return to: `enzyme-to-rtl-migration` for conversion issues, `prettier --write` for formatting

**Final summary**: X / Y files pass — list files needing corrections.
