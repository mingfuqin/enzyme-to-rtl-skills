---
name: enzyme-to-rtl-migration-validation
description: Five-layer validation workflow for RTL-migrated test files. Checks test passage, lint, format, types, and removal of Enzyme patterns. Use after migrating Enzyme tests to React Testing Library, or to validate any test file on-demand.
---

# Test File Validation Skill

## Purpose
Systematically validate test files after migration or on-demand to ensure tests pass, code quality is maintained, Enzyme patterns are removed, and test intent is preserved. This skill provides a repeatable five-layer validation workflow that pairs with the [enzyme-to-rtl-migration](../enzyme-to-rtl-migration/SKILL.md) skill.

## Compatibility

Tested with React 16, `@testing-library/react` ≥ 12 (React 16/17 compatible line), `@testing-library/user-event` ≥ 13, and Jest ≥ 27. Commands assume a Jest + ESLint + Prettier + TypeScript stack; adapt to your project's test runner as needed.

## When to Use
- **After RTL migration (Phase 5)**: Validate that converted tests pass and no Enzyme remains
- **Before commit**: Ensure quality gates (lint, format, types) are met
- **On-demand validation**: Quick check of a single file or batch of files
- **Mismatch correction**: Verify fixes for tests that "don't match" the original (from the enzyme-to-rtl-migration mismatch workflow)
- **Regression detection**: Catch side effects from changes to test harness, mocks, or providers
- **Pre-PR submission**: Confirm tests follow the non-negotiable guardrails

## Relationship to Enzyme-to-RTL Migration Skill

This validation skill works in tandem with [enzyme-to-rtl-migration SKILL](../enzyme-to-rtl-migration/SKILL.md):

- **Migration skill**: Phases 1–4 (assess → convert → per-test conversion)
- **Validation skill**: Phase 5 (validate via 5-layer workflow)
- **Migration skill**: Phases 6–7 (repeat & optionally tighten queries)

## Quick Reference

Adapt these to your project's test runner. The commands below assume a Jest + ESLint + Prettier + TypeScript stack.

```bash
# Validate a single file (recommended starting point)
npx jest path/to/file.test.js
npx eslint path/to/file.test.js
npx prettier --check path/to/file.test.js
npx tsc --noEmit   # whole-project type check; not scoped to one file

# Validate full suite (after batch work)
npx jest
```

If your project provides a wrapper script that runs lint + format + jest + types for a single file, prefer it for speed.

### Compact Batch Validation

For larger migration sets, keep validation outputs compact and file-oriented:

- Validate 3-5 files at a time, then summarize before continuing.
- Prefer reporting only layer status and high-level failure reasons unless a specific line needs review.
- When a single file fails, isolate it and rerun the focused single-file validation flow before widening the scope.

---

## Pre-Validation: Load Project Instruction File

Load `.github/instructions/enzyme-to-rtl-migration.instructions.md` if present. Use its rules — `testIdAttribute`, import paths, deprecated helpers — to distinguish real violations from intentional local patterns during each layer.

---

## Five-Layer Validation Workflow

### Layer 1: Syntax & Linting (ESLint)
**Goal**: Catch import errors, unused variables, Enzyme remnants, and code quality issues.

**Command**:
```bash
npx eslint path/to/file.test.js
```

**What it checks**:
- No undefined imports or symbols
- No leftover Enzyme imports (e.g. `from 'enzyme'`, `enzyme-adapter-react-*`, `enzyme-to-json`, or other Enzyme companion packages)
- No Enzyme methods called (`mount()`, `shallow()`, `wrapper.find()`, `wrapper.setState()`)
- No unused variables or imports
- Compliance with project `.eslintrc` rules
- No React/JSX errors

**If linting fails**:
1. Review error output — focus on Enzyme method calls or import paths
2. Check for mixed Enzyme and RTL imports (e.g. `render` from both sources)
3. Ensure all Enzyme imports are removed and RTL helpers are used instead
4. Report each error with file, line, and recommended fix — do not auto-fix; return findings to the calling agent or user

**Pass criteria**: 0 lint errors, 0 Enzyme method references

---

### Layer 2: Code Formatting (Prettier)
**Goal**: Ensure consistent code style for readability and diff clarity.

**Command**:
```bash
npx prettier --check path/to/file.test.js
```

**What it checks**:
- Consistent indentation and spacing
- Line length compliance
- Quote style consistency
- Import/export formatting

**If formatting fails**:
1. Report formatting diffs — note each differing file and line
2. Do not auto-apply; return findings to the calling agent or user to run `npx prettier --write`

**Pass criteria**: 0 formatting diffs

---

### Layer 3: Unit Test Execution (Jest)
**Goal**: Verify all test cases pass and no behavioral regressions were introduced.

**Command**:
```bash
npx jest path/to/file.test.js
```

**What it checks**:
- All `describe()` blocks execute
- All `it()` / `test()` cases pass
- All async operations (`async/await`, promises, `waitFor`) resolve correctly
- Mocks and fixtures work as expected
- No timeout failures or flaky tests
- No unexpected snapshot diffs

**If tests fail — decision tree**:

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| `ReferenceError: shallow is not defined` | Enzyme method not fully migrated | Replace `shallow()`/`mount()` with `render()` |
| `Cannot find module '@testing-library/react'` | Missing RTL import | Add: `import { render, screen, ... } from '@testing-library/react'` |
| `Expected X to have been called` | Mock setup incorrect or not clearing between tests | Add `beforeEach(() => { jest.clearAllMocks(); })` |
| Test times out or hangs | Async operation not awaited | Use `await waitFor()` or `screen.findBy*()` instead of `getBy*()` |
| `Element not found` (getBy/queryBy fails) | Selector or DOM assumption wrong | Use `screen.debug()` to inspect, switch to role/text query |
| Snapshot diff on first run after migration | Code/markup changed | Review diff — if intentional, update; if behavioral, investigate |
| `Cannot read property 'find' of undefined` | `wrapper` is undefined (Enzyme leftover) | Migrate to RTL `render()` and `screen`/`container` queries |

**Pass criteria**: All test cases pass, 0 failures, 0 unintended skipped tests

---

### Layer 4: Type Safety (TypeScript)
**Goal**: Ensure no type errors or missing type information.

**Command**:
```bash
npx tsc --noEmit
```

**What it checks**:
- All imports are typed
- Component props match expected interfaces
- Jest mock types are correct
- No `any` types used inappropriately
- Async/await types align

**If type check fails**:
1. Review the error message — usually a missing type import or prop mismatch
2. Common fixes:
   - Import types: `import type { RenderResult } from '@testing-library/react'`
   - Type mocks: `jest.mock('./Component', () => ({ __esModule: true, default: jest.fn(() => <div />) }))`
   - Ensure fixture data matches component prop types
3. Re-run validation

**Pass criteria**: 0 type errors

---

### Layer 5: Enzyme Remnant Check & Pattern Verification
**Goal**: Verify no Enzyme patterns remain that the linter may have missed, and confirm test intent is preserved against the 9 Validated Conversion Patterns.

**What to check**:
- No `import { mount, shallow } from 'enzyme'` or related intl/enzyme helpers
- No `wrapper.find()`, `wrapper.setState()`, `wrapper.prop()`, `wrapper.instance()`
- No `.simulate('change')`, `.simulate('click')` patterns
- No `.dive()` or `.shallow()` method calls
- No `.length` checks on Enzyme wrappers
- No `sinon.spy()` / `sinon.stub()` (use `jest.fn()` / `jest.mock()`)
- All Enzyme patterns converted using the 9 Validated Conversion Patterns:
  - **Pattern 1**: Class queries → `container.querySelectorAll('.classname')` or `queryByAttribute('class', ...)`
  - **Pattern 2**: ID queries → `queryByAttribute('id', ...)`
  - **Pattern 3**: `data-testid` or project-specific attributes (e.g. `data-qa`, `data-test`) → `screen.getByTestId()` or `queryByAttribute('data-qa', ...)`
  - **Pattern 4**: Component mocking → `jest.mock()` + `expect(Component).toHaveBeenCalledWith()`
  - **Pattern 5**: Render strategy → simple `render()`, `renderWithRedux()`, `renderWithRouter()`, etc.
  - **Pattern 6**: Event triggers → `userEvent.click()` (preferred) or `fireEvent.click()`
  - **Pattern 6b**: Screen-based assertions → `screen.getByRole()`, `screen.getByText()`
  - **Pattern 7**: Async updates → `await screen.findByText()` or `await waitFor()`
  - **Pattern 8**: Mock spies → `jest.fn()` + `toHaveBeenCalledWith()`
  - **Pattern 9**: Helper imports → `render`, `screen`, `waitFor`, `userEvent`, `queryByAttribute`
- Test assertions check observable behavior, not internal component state
- All 8 non-negotiable guardrails followed (see migration skill):
  1. Test intent preserved
  2. Regression recovery via harness fixes (not weakened assertions)
  3. Selector preservation during migration
  4. Mock cleanup in `beforeEach`
  5. Production code off-limits
  6. Deterministic tests (explicit waits, fixed fixtures)
  7. Component-path validation preserved
  8. Scope discipline (test files only)

**Grep commands to find remnants**:
```bash
grep -nE "from 'enzyme'" path/to/file.test.js
grep -nE "wrapper\." path/to/file.test.js   # review matches — non-Enzyme `wrapper` variables are fine
grep -nE "\.simulate\(" path/to/file.test.js
grep -nE "\bsinon\." path/to/file.test.js
grep -nE "\bmount\(|\bshallow\(" path/to/file.test.js
```

**Verify test case names are preserved**:
Compare the original Enzyme test file with the migrated RTL version:
```bash
# Extract test names from original (git history)
git show HEAD:path/to/file.test.js | grep -nE "describe\(|it\(|test\(" | grep -oP "['\"]\K[^'\"]*(?=['\"])"

# Extract test names from migrated version
grep -nE "describe\(|it\(|test\(" path/to/file.test.js | grep -oP "['\"]\K[^'\"]*(?=['\"])"

# Compare manually or pipe to diff
git show HEAD:path/to/file.test.js > /tmp/original.test.js
diff <(grep -oP "describe\(|it\(|test\(" /tmp/original.test.js | grep -oP "['\"]\K[^'\"]*(?=['\"])") \
     <(grep -oP "describe\(|it\(|test\(" path/to/file.test.js | grep -oP "['\"]\K[^'\"]*(?=['\"])")
```

All `describe()` block names and `it()` / `test()` descriptions **must match exactly**. Test names are part of the test contract and communicate intent — do not rename, simplify, or consolidate during migration.

**If remnants found**:
1. Report each remnant with file, line, and the recommended Conversion Pattern from the [9 Validated Conversion Patterns](../enzyme-to-rtl-migration/SKILL.md#reference-9-validated-conversion-patterns)
2. Return findings — do not convert; the calling agent applies corrections

**Intent verification checklist**:
- [ ] All test case names (`describe()` blocks and `it()` / `test()` descriptions) are preserved exactly as in the original
- [ ] Original test scenario is still being tested
- [ ] Assertions check the same business outcomes
- [ ] Mocks are set up for the same components
- [ ] No assertions were removed or weakened
- [ ] Async operations properly await results
- [ ] All 8 guardrails followed

**Pass criteria**: 0 Enzyme references, intent preserved, all guardrails met

---

## Mismatch Detection & Reporting (Phase 5 Enhancement)

When a converted test "doesn't match" the original, use this workflow to diagnose and fix.

### Indicators
- "This test still doesn't work"
- "I converted it but an assertion is missing"
- "The test passes but doesn't check what the original did"
- "Expect in this test still doesn't match"

### Step-by-Step Correction

1. **Parse context**: Identify test name, file, and specific issue
2. **Fetch original**: `git show HEAD:path/to/file.test.js` (or check VCS history) for the original Enzyme version
3. **Compare side-by-side**:
   - Original Enzyme pattern (e.g. `wrapper.find(Component)`)
   - Current RTL query (e.g. `screen.getByTestId(...)`)
   - Expected RTL equivalent from the 9 Validated Patterns
4. **Analyze the gap**: Is the selector capturing the right element? Is the render strategy correct?
5. **Report the gap**: State the expected RTL equivalent from the [9 Validated Conversion Patterns](../enzyme-to-rtl-migration/SKILL.md#reference-9-validated-conversion-patterns) and why the current conversion falls short
6. **Return findings**: Hand off the structured report to the calling agent or user for correction — do not apply fixes

### Example: Mismatch Correction

**Original (Enzyme)**:
```javascript
const wrapper = mount(<MyModal {...props} />);
expect(wrapper.find(GridList).length).toEqual(1);
expect(wrapper.find('.grid-list__actions').length).toEqual(0);
```

**First conversion attempt (incomplete)**:
```javascript
render(<MyModal {...props} />);
// Missing: GridList component verification
// Missing: actions class check
```

**Expected correction (for the calling agent or user to apply) using Pattern 4 & Pattern 1**:
```javascript
import { GridList } from './GridList';

jest.mock('./GridList', () => ({
  __esModule: true,
  GridList: jest.fn(() => <div data-testid="grid-list" />),
}));

const { container } = render(<MyModal {...props} />);

// Pattern 4: verify GridList was rendered
expect(GridList).toHaveBeenCalled();

// Pattern 1: verify the actions class is absent
expect(container.querySelectorAll('.grid-list__actions')).toHaveLength(0);
```

**Validation**: Re-run focused Jest + ESLint + tsc.

---

## Assertion Inventory Verification

For each migrated test, create a side-by-side comparison:

```
Original Enzyme Test                          → Migrated RTL Test
─────────────────────────────────────────────────────────────────────────────
wrapper.find(Component)                       → Query for component / mock & verify call (Pattern 4)
wrapper.find('.className')                    → container.querySelectorAll('.className') (Pattern 1)
wrapper.find('#id')                           → queryByAttribute('id', container, 'id') (Pattern 2)
wrapper.find('[data-testid="value"]')         → screen.getByTestId('value') (Pattern 3)
wrapper.props().history.location              → Mock history.push + verify call (Pattern 5/8)
wrapper.setState({})                          → Pass state via props or trigger via UI (Pattern 5)
wrapper.find(...).length === 0                → Query returns empty (Pattern 1/3/6b)
wrapper.find(...).length === 1                → Query returns a single element (Pattern 1/3/6b)
wrapper.instance().method()                   → Trigger via user interaction (Pattern 6)
button.simulate('click')                      → fireEvent.click() / userEvent.click() (Pattern 6)
wrapper.setProps({}); wrapper.update()        → rerender(...) or findBy* for async (Pattern 7)
wrapper.find(Comp).prop('prop')               → expect(Comp).toHaveBeenCalledWith(...) (Pattern 4)
```

### Assertion Inventory Checklist

For each test, answer ✅ (migrated) or ❌ (missing):

1. **Component rendering**
   - [ ] Component renders in the DOM
   - [ ] Component has correct props
   - [ ] Component children/slots render correctly

2. **Child components**
   - [ ] All child components from the original test are verified
   - [ ] Grid/List components render (if used in original)
   - [ ] Modal/Dialog components render (if used)
   - [ ] Conditional components appear/disappear correctly

3. **DOM elements & classes**
   - [ ] Loading states verified
   - [ ] Error states verified
   - [ ] All `.className` queries from the original are migrated
   - [ ] Empty states verify elements are absent (length === 0)

4. **Events & user interactions**
   - [ ] Button clicks trigger the correct handlers
   - [ ] Form inputs update state
   - [ ] Callbacks/props are called with correct arguments

5. **Navigation & routing**
   - [ ] Links navigate to correct paths
   - [ ] `history.push` called with correct path/state
   - [ ] Redirect components render the correct routes

6. **Data & state**
   - [ ] Mock data/props are identical
   - [ ] State changes produce the expected DOM updates
   - [ ] Async data loading shows loading → success/error states

**Pass criteria**: All original assertions have RTL equivalents.

---

## Layer 5.5: Assertion Quality Verification (Pre-commit Gate)

**Purpose**: Detect and prevent weak, placeholder, or insufficient assertions from being committed. This catches cases where tests pass but don't actually verify component behavior.

### ❌ Anti-patterns (Red flags — must be fixed)

| Pattern | Problem | Fix |
|---------|---------|-----|
| `expect(container).toBeInTheDocument()` | Placeholder — only verifies render | Assert on specific text/role/mock call |
| `expect(screen.getByRole('*')).toBeInTheDocument()` | Generic role check | Verify specific text, attributes, or mock calls |
| Mocked components never asserted on | Mocks exist but unused | Add `expect(Mock).toHaveBeenCalledWith(expected)` |
| `expect(container.querySelector(sel)).toBeTruthy()` | Vague | Use `toHaveTextContent`, `toHaveAttribute`, etc. |
| Multiple tests with identical assertions | Copy-paste smell | Differentiate assertions per scenario |
| `// Verify component renders` (comment in place of assertion) | No actual check | Replace with a real `expect()` |

### ✅ Meaningful assertions

```javascript
// Component interaction verification
expect(GridList).toHaveBeenCalledWith(
  expect.objectContaining({ items: expectedData }),
  expect.anything(),
);

// DOM state with specificity
expect(container.querySelectorAll('.error-state')).toHaveLength(0);
expect(screen.getByText('Loading...')).toBeInTheDocument();

// Mock call verification
expect(historyPush).toHaveBeenCalledWith('/next-route', { state: value });

// Conditional rendering
expect(screen.queryByTestId('empty-message')).not.toBeInTheDocument();
expect(screen.getByTestId('data-table')).toBeInTheDocument();

// Prop-based logic
expect(SplitPane).toHaveBeenCalledWith(
  expect.objectContaining({ primary: 'second', defaultSize: '200px' }),
  expect.anything(),
);
```

### Detection commands

```bash
# Placeholder assertions
grep -n "expect(container).toBeInTheDocument()" path/to/file.test.js
grep -nE "// *Verify component renders" path/to/file.test.js
grep -n "expect(screen.getByRole('div')).toBeInTheDocument()" path/to/file.test.js

# Mocks that may not be verified
grep -n "jest.mock" path/to/file.test.js
# Then confirm each mock has a matching expect(...).toHaveBeenCalled* call
```

### Verification checklist
- [ ] Has a specific assertion — not just `toBeInTheDocument()` on `container`
- [ ] Verifies component behavior — props, calls, or DOM state
- [ ] Tests one scenario — single logical outcome
- [ ] Mocks are verified — `expect(Mock).toHaveBeenCalledWith(...)`
- [ ] No comment-only assertions
- [ ] Intent is clear from reading the assertion

---

## Full Suite Validation

**When to run**: After validating several files individually, or before final commit.

**Command**:
```bash
npx jest
```

**If the full suite fails**:
1. Identify which test file caused the failure from the Jest output
2. Run that file in isolation: `npx jest path/to/file.test.js`
3. Report identified failures with a diagnosis from the troubleshooting guide — do not apply fixes
4. Return findings to the calling agent or user to correct, then re-validate

---

## Validation Modes

### Mode: Single file (recommended during migration)
```bash
npx eslint path/to/file.test.js && \
  npx prettier --check path/to/file.test.js && \
  npx jest path/to/file.test.js && \
  npx tsc --noEmit
```
- Runs all five layers for one file
- Fast feedback loop
- Use after each file migration

### Mode: Batch (a few files)
Run the single-file flow for each migrated file before moving on to full-suite validation.

### Mode: Full suite (pre-PR)
```bash
npx jest && npx tsc --noEmit
```

---

## Full Validation Checklist (Pre-PR)

- [ ] **Test case names**: All `describe()` blocks and `it()` / `test()` descriptions match the original exactly
- [ ] **Assertion inventory**: Comparison table created, all conditions migrated
- [ ] **Enzyme remnants**: No grep matches for Enzyme imports or methods
- [ ] **Assertion quality (Layer 5.5)**: No placeholders like `expect(container).toBeInTheDocument()` standing in for real checks
- [ ] **Mocks verified**: Every mocked component has `toHaveBeenCalled*` assertions
- [ ] **Patterns applied**: Conversions use the 9 Validated Conversion Patterns
- [ ] **Guardrails met**: All 8 non-negotiable guardrails verified
- [ ] **Lint**: ESLint passes (0 errors)
- [ ] **Format**: Prettier passes (`--check` clean)
- [ ] **Jest**: All tests pass with no timeouts
- [ ] **Types**: `tsc --noEmit` passes
- [ ] **Test intent**: Each test still verifies the original business scenario
- [ ] **No regressions**: Full suite passes after local validation
