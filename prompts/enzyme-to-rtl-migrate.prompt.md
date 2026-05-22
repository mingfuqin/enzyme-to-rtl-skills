---
name: enzyme-to-rtl-migrate
description: Migrate a single Enzyme test file to React Testing Library using the 5-phase workflow
argument-hint: path to the Enzyme test file (e.g. src/test/containers/Foo.test.js)
---

# Enzyme-to-RTL Migration (Single File)

Migrate the test file provided by the user using the `enzyme-to-rtl-migration` skill.

## Step 0: Load project instruction file

Load `.github/instructions/enzyme-to-rtl-migration.instructions.md` if present; its rules override all defaults below.

## Phase 1: Pre-Migration Assessment

1. Measure complexity (`wc -l <file>` and `grep -cE "it\(|test\(" <file>`) and classify using the risk tiers in the migration skill (low / medium / high).

2. Identify dependencies: Redux store, Router, IntlProvider, async operations, component mocks.

3. Map Enzyme patterns: `mount()`, `shallow()`, `wrapper.find()`, `wrapper.setState()`,
   `jest.spy()` / `sinon.spy()`, async patterns.

## Phase 2: Update Imports

Remove all Enzyme imports. Add RTL imports using the project's authoritative import paths
from the instruction file, or fall back to:

```javascript
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
```

Prefer the project's custom render helpers (`renderWithRedux`, `renderWithRouter`, etc.)
over re-wrapping providers manually.

## Phase 3: Selector Decision Tree

For each `wrapper.find(...)`, follow this order:
- Semantic element (button/link/heading) → `screen.getByRole(...)`
- `data-testid` / `data-qa` → `screen.getByTestId(...)` or `queryByAttribute('data-qa', ...)`
- `#id` selector → `queryByAttribute('id', container, 'id-value')`
- `.class` selector → `container.querySelectorAll('.classname')`
- Component/node type → `jest.mock()` + `expect(Component).toHaveBeenCalledWith(...)`
- Async → `await screen.findByText(...)` or `waitFor(...)`
- State-change → assert on resulting UI (text/role), not internal state

## Phase 4: Per-Test Conversion

**Conversion discipline**: convert line-by-line. Do not extract helpers, refactor structure,
or optimize. Reuse existing project helpers but create no new ones.

- Preserve all `describe()` and `it()` names exactly — no renaming or consolidating.
- `mount(<C />)` → `const { container } = render(<C />)`
- `.simulate('click')` → `await userEvent.click(...)` or `fireEvent.click(...)`
- `wrapper.update()` + sync check → `await screen.findByText(...)` or `waitFor(...)`
- `wrapper.setProps({...})` → `rerender(<Component newProps />)` then await UI

For high-risk files: convert one chunk (5–7 tests), validate with a focused Jest run,
then proceed to the next chunk.

## Phase 5: Validate

Run the verify script:

```bash
.github/skills/enzyme-to-rtl-migration/verify.sh <file>
```

This covers ESLint auto-fix, Prettier, Jest, TypeScript (if TS), and Enzyme remnant grep.

Checklist:
- [ ] Layer 1 — Lint: no errors
- [ ] Layer 2 — Format: Prettier passes
- [ ] Layer 3 — Jest: all tests pass, no timeouts
- [ ] Layer 4 — Types (if TS): `tsc --noEmit` passes
- [ ] Layer 5 — No Enzyme remnants: `enzyme`, `mount(`, `shallow(`, `wrapper.` → no matches
- [ ] Test intent preserved: each scenario still tests the same business outcome

If a converted test fails, fix the test harness (providers, fixtures, mocks) **before**
changing expected behavior. Do not weaken assertions to make tests pass.

> For deeper pre-PR validation (assertion-quality gate, mismatch correction), invoke the
> `enzyme-to-rtl-validate` prompt.
