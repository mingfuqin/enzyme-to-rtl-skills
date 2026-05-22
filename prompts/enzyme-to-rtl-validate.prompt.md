---
name: enzyme-to-rtl-validate
description: Run all 5 validation layers on an Enzyme-to-RTL migrated test file and report findings
argument-hint: path to the migrated test file (e.g. src/test/containers/Foo.test.js)
---

# Enzyme-to-RTL Migration Validation

Validate the test file provided by the user using the `enzyme-to-rtl-migration-validation` skill.

## Step 0: Load project instruction file

Load `.github/instructions/enzyme-to-rtl-migration.instructions.md` if present; use its rules as the reference throughout.

## Run all 5 layers

For the file provided:

1. **Layer 1 — Lint**: `npx eslint <file>`
2. **Layer 2 — Format**: `npx prettier --check <file>`
3. **Layer 3 — Jest**: `npx jest <file> --no-coverage` (run from the appropriate workspace root if using a monorepo)
4. **Layer 4 — Types**: `npx tsc --noEmit`
5. **Layer 5 — Enzyme remnants**: grep for `from 'enzyme'`, `from 'enzyme-adapter`, `.simulate(`,
   `\bshallow\(`, `\bmount\(`, `wrapper\.`, `sinon\.`

Also run **Layer 5.5 — Assertion quality**: check for placeholder assertions
(`expect(container).toBeInTheDocument()`), mocked components never asserted on,
and `// Verify component renders` comments substituting for real expectations.

## Report

Return a structured report — **do not apply any fixes**. Return findings to the user for correction.

| Layer | Status | Issues |
|-------|--------|--------|
| 1 Lint | ✅ / ❌ | |
| 2 Format | ✅ / ❌ | |
| 3 Jest | ✅ / ❌ | |
| 4 Types | ✅ / ❌ | |
| 5 Enzyme remnants | ✅ / ❌ | |
| 5.5 Assertion quality | ✅ / ❌ | |

For each ❌:
- File, line number, and exact error or match
- Recommended fix (which of the 9 Validated Conversion Patterns applies, or the specific command to run)
- Which skill to return to: `enzyme-to-rtl-migration` for conversion issues, `prettier --write` for formatting

**Final status**: PASS (all layers ✅) or NEEDS FIXES (list layers that failed).
