---
name: enzyme-to-rtl-migration
description: Systematic conversion of Enzyme tests to React Testing Library using validated patterns that preserve test intent and minimize regressions.
triggers:
  - "migrate enzyme tests"
  - "convert enzyme to rtl"
  - "convert to react testing library"
  - "enzyme to testing library"
  - "rewrite enzyme test"
  - "enzyme → rtl"
  - "doesn't match"
  - "missed"
  - "still wrong"
context:
  - "Enzyme imports present (from 'enzyme')"
  - "mount() or shallow() in test file"
  - "wrapper.find() / wrapper.simulate() / wrapper.prop() usage"
applicableTo:
  - "**/*.test.js"
  - "**/*.test.jsx"
  - "**/*.test.ts"
  - "**/*.test.tsx"
  - "**/*.spec.js"
  - "**/*.spec.jsx"
  - "**/*.spec.ts"
  - "**/*.spec.tsx"
type: "migration"
domain: "testing"

sessionContextIndicators:
  - "Test file paths, attachments, or jest output shown in conversation"
  - "User mentions 'migrate', 'convert', 'batch', 'doesn't match', or 'still wrong'"
  - "Conversation includes git diff or staged changes to test files"
autoScanPatterns: "from 'enzyme', mount(, shallow(, wrapper.find, wrapper.setState, wrapper.simulate, wrapper.prop(, wrapper.state(, wrapper.instance("
---

# Enzyme → React Testing Library Migration Skill

An open-source, framework-agnostic skill for systematically converting Enzyme-based tests to React Testing Library (RTL) while preserving test intent and minimizing regressions.

---

## Core Principle: Selector-Intent Preservation

Original test assertions and selectors should be preserved as closely as possible rather than refactored to "best practice" RTL patterns mid-migration. This minimizes behavioral drift and keeps diffs reviewable. Refactor to richer queries (role/label/text) in a follow-up pass once the migration is green.

**Test case name preservation**: All test descriptions (`describe()` blocks and `it()` names) must be preserved exactly as they appear in the original Enzyme test. Do not rename, simplify, or consolidate test names during migration. Test names are part of the contract and communicate test intent to developers.

**Line-by-line conversion**: Convert Enzyme code directly to RTL equivalents without optimization. Do not extract duplicate code into new helper functions, refactor test structure, or simplify test logic. Reuse existing project helpers if available, but create no new ones. This keeps diffs focused, reviewable, and easier to validate.

**Low-token batch rule**: process 3-5 files per chunk, report only file paths plus pass/fail summaries, and avoid re-sending full file contents unless a specific assertion mismatch must be debugged.

---

## When to Use This Skill

- **Converting Enzyme tests**: `mount()`, `shallow()`, `wrapper.find()`, `wrapper.setState()`
- **Preserving test intent**: Tests with specific business expectations that must not change
- **Risk-ordered migration**: Working through files from low → medium → high complexity using `.github/instructions/enzyme-to-rtl-migration-queue.md` as the authoritative backlog
- **Batched execution**: Migrating multiple files with consistent patterns
- **Regression prevention**: Need deterministic, stable conversions
- **Mismatch auto-correction**: When converted tests "don't match" the original — the skill auto-detects, compares original/current, and corrects

**Triggers**: "migrate enzyme tests", "convert to RTL", "enzyme → testing library", "doesn't match", "missed", "still wrong"

## Related Skills

- [`enzyme-to-rtl-migration-validation`](../enzyme-to-rtl-migration-validation/SKILL.md) — companion skill providing a deeper five-layer validation workflow (lint, format, jest, types, Enzyme remnant check + assertion-quality gate). This migration skill includes its own lightweight Phase 5 validation; invoke `enzyme-to-rtl-migration-validation` only when the user explicitly asks for deeper validation, pre-PR checks, or mismatch correction beyond what Phase 5 covers.

---

## Workflow: Enzyme → RTL Migration

### Phase 1: Pre-Migration Assessment

0. **Load project context files** — Read both if they exist:

   - `.github/instructions/enzyme-to-rtl-migration.instructions.md` — overrides generic guidance for import paths, render helpers, `testIdAttribute`, and deprecated selectors.
   - `.github/instructions/enzyme-to-rtl-migration-queue.md` — pick the first unchecked `- [ ]` entry when no file is specified; mark it `- [x]` after success.

1. **Measure complexity**
   ```bash
   wc -l <file.test.js>
   grep -cE "it\(|test\(" <file.test.js>
   ```
   - `< 100` lines / `< 5` tests → low risk
   - `100–300` lines / `5–15` tests → medium risk
   - `> 300` lines / `> 15` tests → high risk (chunk the work)

2. **Identify dependencies**
   - Redux store wrapping? → Need a Redux `<Provider>` wrapper
   - Router navigation? → Need `MemoryRouter` or similar
   - Internationalization? → Need `IntlProvider` (or equivalent)
   - Component mocks? → Document which components are mocked
   - Async operations? → Mark for `waitFor` / `findBy`

3. **Map test patterns** (grep for)
   - `mount()` / `shallow()` → Render approach needed
   - `wrapper.find()` → Selector pattern needed (class, id, data-testid, component)
   - `wrapper.setState()` → Behavior assertion needed
   - `jest.spy()` or `sinon.spy()` or `jest.spyOn()` → Mock strategy needed
   - Async patterns (`await wait()`, `.resolves`) → `waitFor` / `findBy` needed

### Phase 2: Update Imports

```javascript
// ❌ Remove
import { mount, shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';

// ✅ Add
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
```

If your project provides custom render helpers (e.g. wrappers that supply Redux, Router, or Intl providers), prefer those instead of re-wrapping providers in every test. Check the project instruction file (`.github/instructions/enzyme-to-rtl-migration.instructions.md`) for the authoritative import paths and helper names for this codebase. See the **Custom Render Helpers** section below for a generic reference implementation.

**Recommended import ordering:**
```javascript
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

import { ComponentUnderTest } from './ComponentUnderTest';
```

### Phase 3: Selector Decision Tree

For each `wrapper.find(...)`:

```
Is it a semantic element (button/link/heading/etc.)?
  └─ YES → Pattern 6b: screen.getByRole(...) / getByLabelText(...)
  └─ NO ↓

Is it a data-testid (or data-qa) attribute?
  └─ YES — is the value a descriptive name (e.g. "submit-button")?
    └─ Descriptive → Pattern 3: screen.getByTestId(...)
    └─ Hash/opaque (e.g. "xB3mK9nP2rQ8sVwY") → check the source component:
        Does it have visible text or an accessible role?
          └─ YES → prefer Pattern 6b: screen.getByRole('button', { name: /text/i })
                   or screen.getByLabelText / screen.getByText
          └─ NO  → Pattern 3: screen.getByTestId(...) as fallback
  └─ NO ↓

Is it an id selector?
  └─ YES → Pattern 2: queryByAttribute('id', container, 'id-value')
  └─ NO ↓

Is it a class selector (legacy)?
  └─ YES → Pattern 1: container.querySelectorAll('.classname') /
            queryByAttribute('class', container, 'className')
  └─ NO ↓

Is it a component/node type check?
  └─ YES → Pattern 4: jest.mock() the component + assert toHaveBeenCalled / toHaveBeenCalledWith
  └─ NO ↓

Is it an async update?
  └─ YES → Pattern 7: await screen.findByText(...) or waitFor(...)
  └─ NO ↓

Is it a state-change verification?
  └─ YES → Pattern 6b: Assert on resulting UI (text/role) instead of internal state
```

### Phase 4: Per-Test Conversion

**Conversion discipline**: Convert Enzyme patterns directly to RTL equivalents. Do not optimize, extract common patterns into new helpers, or refactor test logic. Keep changes line-by-line and focused on Enzyme→RTL translation only. Reuse existing project helpers (`renderWithRedux`, `queryByAttribute`, etc.) but do not create new ones.

#### 4.1 Preserve test case names
```javascript
// ✅ CORRECT: Keep the original test description
describe('when loading hasn\'t started', () => {
  it('shows as loading', () => {
    // conversion code here
  });
});

// ❌ WRONG: Do not simplify or rename test cases
describe('loading state', () => {
  it('renders', () => {
    // conversion code here
  });
});
```

#### 4.2 Replace the render call
```javascript
// BEFORE
const wrapper = mount(<Component {...props} />);

// AFTER
const { container } = render(<Component {...props} />);
```

#### 4.3 Convert selectors and assertions
Apply the patterns in the Reference section.

#### 4.4 Convert events
```javascript
// BEFORE
wrapper.find('button').simulate('click');

// AFTER (preferred)
await userEvent.click(screen.getByRole('button', { name: /save/i }));

// AFTER (fireEvent — when userEvent is not available)
fireEvent.click(screen.getByRole('button', { name: /save/i }));
```

#### 4.5 Convert async updates
```javascript
// BEFORE
wrapper.update();
expect(wrapper.find('.result').text()).toContain('Done');

// AFTER
expect(await screen.findByText(/Done/i)).toBeInTheDocument();
```

### Phase 5: Validate

Run `verify.sh` — it covers all automated layers in one command (ESLint auto-fix, Prettier, Jest, TypeScript, Enzyme remnant grep):

```bash
.github/skills/enzyme-to-rtl-migration/verify.sh <path-to-file.test.js>
```

**Validation checklist:**

- **Layer 1 — Lint** — ESLint auto-fix runs; no errors remain
- **Layer 2 — Format** — Prettier auto-fix applied
- **Layer 3 — Jest** — All tests pass, no timeouts, proper assertions
- **Layer 4 — Types (if TS)** — `tsc --noEmit` passes
- **Layer 5 — No Enzyme remnants** — grep for `enzyme`, `mount(`, `shallow(`, `wrapper.` returns no matches
- **Test intent preserved** (manual review)
  - Each test scenario is still being tested
  - Assertions check the same business outcomes
  - No assertions removed or weakened
  - Mocks set up for the same components

If a converted test fails, fix the test setup/harness (providers, fixtures, mocks) **before** changing expected behavior.

> **Need deeper validation?** The companion [`enzyme-to-rtl-migration-validation`](../enzyme-to-rtl-migration-validation/SKILL.md) skill offers a five-layer workflow (with an assertion-quality gate and mismatch-correction playbook). Use it on demand — e.g. when the user asks for pre-PR validation, batch validation, or fixing a "doesn't match" complaint that Phase 5 alone hasn't resolved. Otherwise stick with the Phase 5 checklist above.

---

## Reference: 9 Validated Conversion Patterns

Each Enzyme pattern maps to one or more RTL equivalents. Use this as your source of truth during conversion.

### Pattern 1 — Class Queries

```javascript
// BEFORE
wrapper.find('.modal-header');

// AFTER (option A — direct DOM query)
container.querySelector('.modal-header');

// AFTER (option B — with helper)
queryByAttribute('class', container, 'modal-header');
```

**ESLint disable comment placement** — Projects with `testing-library/no-container` and
`testing-library/no-node-access` rules require a suppress comment. Prettier often wraps
`expect(container.querySelector(...))` across multiple lines. `eslint-disable-next-line`
only suppresses the **immediately following line**, so the comment must go **inside**
the `expect()` call, directly above `container.querySelector`:

```javascript
// ❌ WRONG — comment suppresses `expect(`, not `container.querySelector`
// eslint-disable-next-line testing-library/no-container, testing-library/no-node-access
expect(
  container.querySelector('.modal-header'),
).toBeInTheDocument();

// ✅ CORRECT — comment is directly above the violating line
expect(
  // eslint-disable-next-line testing-library/no-container, testing-library/no-node-access
  container.querySelector('.modal-header'),
).toBeInTheDocument();
```

> **Follow-up task**: `eslint-disable` comments here are a migration-phase escape hatch.
> After migration, add `data-qa` attributes to the component and replace these assertions
> with `screen.getByTestId(...)` (Pattern 3), then remove the disable comments.

---

### Pattern 2 — ID Queries

```javascript
// BEFORE
wrapper.find('#submit-button');

// AFTER
queryByAttribute('id', container, 'submit-button');
// or, for inputs:
screen.getByDisplayValue(/.../);
```

| Enzyme | RTL | Use Case |
|--------|-----|----------|
| `wrapper.find('#id-value')` | `queryByAttribute('id', container, 'id-value')` | Query by id |

---

### Pattern 3 — Data-TestId / Data-Qa Queries

**Preference rule**: Check whether the `data-qa` value is descriptive or a hash-like opaque ID.

- **Descriptive** (`data-qa="submit-button"`, `data-qa="user-menu"`) → use `screen.getByTestId()`
- **Hash/opaque** (`data-qa="xB3mK9nP2rQ8sVwY"`) → look up the source component first:
  - If it has visible text → `screen.getByRole('button', { name: /text/i })` or `screen.getByText(/text/i)`
  - If it has a label → `screen.getByLabelText('Label text')`
  - If no semantic alternative exists → fall back to `screen.getByTestId(hash)`

```javascript
// BEFORE
wrapper.find('[data-testid="action-menu"]');
wrapper.find('[data-qa="action-menu"]');

// AFTER — descriptive ID → keep getByTestId
screen.getByTestId('action-menu');

// AFTER — opaque hash ID + button with text "Save"
// ✅ preferred: semantic query
screen.getByRole('button', { name: /^Save$/ });
// ⚠️ fallback only when no semantic alternative:
screen.getByTestId('xB3mK9nP2rQ8sVwY');
```

| Enzyme | RTL | Use Case |
|--------|-----|----------|
| `wrapper.find('[data-qa="descriptive-name"]')` | `screen.getByTestId('descriptive-name')` | Descriptive ID |
| `wrapper.find('[data-qa="hash..."]')` + element has text | `screen.getByRole(..., { name: /text/ })` | Hash ID — prefer semantic |
| `wrapper.find('[data-qa="hash..."]')` + no semantic anchor | `screen.getByTestId('hash...')` | Hash ID — fallback |

---

### Pattern 4 — Component Mocking

```javascript
// BEFORE
const dropdown = wrapper.find(Dropdown);
expect(dropdown.prop('label')).toEqual('Date Range');

// AFTER
import { Dropdown } from './Dropdown';

jest.mock('./Dropdown', () => ({
  __esModule: true,
  Dropdown: jest.fn(({ label, children }) => (
    <div data-testid="dropdown">{label}{children}</div>
  )),
}));

beforeEach(() => {
  jest.clearAllMocks();
});

// In test
expect(Dropdown).toHaveBeenCalled();
expect(Dropdown).toHaveBeenCalledWith(
  expect.objectContaining({ label: 'Date Range' }),
  expect.anything(),
);
```

| Enzyme | RTL | Use Case |
|--------|-----|----------|
| `wrapper.find(Component)` | `jest.mock()` + `expect(Component).toHaveBeenCalled()` | Verify rendered |
| `wrapper.find(Component).prop('p')` | `expect(Component).toHaveBeenCalledWith(expect.objectContaining({ p }), ...)` | Verify props |

---

### Pattern 5 — Render Strategy Selection

| Enzyme | RTL | Use Case |
|--------|-----|----------|
| `mount(<Component />)` | `render(<Component />)` | Simple component |
| Redux-wrapped | `render(ui, { wrapper: ReduxProvider })` or custom `renderWithRedux` | Redux-connected |
| Router component | `render(ui, { wrapper: MemoryRouter })` or `renderWithRouter` | Uses router |
| Redux + Router | Compose providers in a single wrapper | Both Redux & Router |
| Intl component | Wrap with `IntlProvider` (or your i18n provider) | Needs i18n |
| `shallow(<Component />)` | `render(<Component />)` and assert on behavior | Test behavior, not internals |

---

### Pattern 6 — Event Triggers

```javascript
// BEFORE
wrapper.find('button').simulate('click');

// AFTER (fireEvent — simple)
fireEvent.click(screen.getByRole('button', { name: /Click Me/i }));

// AFTER (userEvent — preferred, simulates real user)
const user = userEvent.setup();
await user.click(screen.getByRole('button', { name: /Click Me/i }));
```

| Enzyme | RTL (fireEvent) | RTL (userEvent — preferred) |
|--------|-----------------|-----------------------------|
| `.simulate('click')` | `fireEvent.click(el)` | `await user.click(el)` |
| `.simulate('change', { target: { value } })` | `fireEvent.change(el, { target: { value } })` | `await user.type(el, value)` |
| `.simulate('submit')` | `fireEvent.submit(form)` | `await user.click(submitButton)` |

---

### Pattern 6b — Screen-Based Assertions & Container Queries

```javascript
// BEFORE
expect(wrapper.find('button').text()).toContain('Save');

// AFTER (preferred — semantic)
expect(screen.getByRole('button', { name: /Save/i })).toBeInTheDocument();

// AFTER (text query)
expect(screen.getByText(/Save/i)).toBeInTheDocument();

// AFTER (container-based for legacy class queries)
expect(container.querySelectorAll('.active').length).toBeGreaterThan(0);
```

| Enzyme | RTL |
|--------|-----|
| `wrapper.find('button').text()` | `screen.getByRole('button').textContent` |
| `wrapper.find('button').text().includes('x')` | `expect(screen.getByText(/x/i)).toBeInTheDocument()` |
| `wrapper.find('.error').exists()` | `screen.queryByText(/error/i) !== null` |
| `!wrapper.find('.error').exists()` | `expect(screen.queryByText(/error/i)).not.toBeInTheDocument()` |

---

### Pattern 7 — Async Updates

```javascript
// BEFORE
act(() => {
  wrapper.setProps({ loading: false });
});
wrapper.update();
expect(wrapper.find('.result').text()).toContain('Done');

// AFTER (findBy — waits up to default timeout)
expect(await screen.findByText(/Done/i)).toBeInTheDocument();

// OR explicit waitFor
await waitFor(() => {
  expect(screen.getByText(/Loaded/i)).toBeInTheDocument();
});
```

| Enzyme | RTL |
|--------|-----|
| `wrapper.update()` | `await screen.findByText(...)` or `await waitFor(...)` |
| `act(() => { ... })` | `render()` and event helpers handle `act` internally |
| `wrapper.setProps({...})` then check | `rerender(<Component newProps />)` then await async UI |

---

### Pattern 8 — Mock Spies with Verification

```javascript
// BEFORE
wrapper.find(Dependency).prop('onClick')();

// AFTER
jest.mock('./Dependency', () => ({
  __esModule: true,
  default: jest.fn(() => <div>mocked</div>),
}));

beforeEach(() => {
  jest.clearAllMocks();
});

// Verify
expect(Dependency).toHaveBeenCalled();
expect(Dependency).toHaveBeenCalledWith(
  expect.objectContaining({ onClick: expect.any(Function) }),
  expect.anything(),
);
```

| Enzyme | RTL |
|--------|-----|
| `wrapper.instance().method()` | `jest.fn()` mock + verify calls |
| Method-was-called check | `expect(mockFn).toHaveBeenCalled()` |
| Specific args | `expect(mockFn).toHaveBeenCalledWith(args)` |
| Clean state between tests | `jest.clearAllMocks()` in `beforeEach` |

---

### Pattern 9 — Helper Imports Template

```javascript
import {
  render,
  screen,
  fireEvent,
  waitFor,
  within,
  queryByAttribute,
} from '@testing-library/react';
import userEvent from '@testing-library/user-event';
```

**Useful query patterns:**

| Helper | Purpose |
|--------|---------|
| `screen.getByRole(role, options)` | Find by accessible role (button, dialog, etc.) — preferred |
| `screen.getByLabelText(text)` | Find form controls by label — preferred for forms |
| `screen.getByText(text)` | Find by text content |
| `screen.getByTestId(id)` | Find by `data-testid` — escape hatch |
| `screen.queryBy*` | Same as `getBy*` but returns `null` instead of throwing |
| `screen.findBy*` | Async version; waits until element appears |
| `within(element).getBy*` | Scope queries to a subtree |
| `queryByAttribute(attr, container, value)` | Generic attribute query (legacy fallback) |

**Query and assertion guidance:**

1. Query priority order during migration: `getByRole` → `getByLabelText` → `getByPlaceholderText` → `getByText` → `getByDisplayValue` → `getByAltText` → `getByTitle` → `getByTestId`. Use `getByTestId` only when the `data-qa` value is descriptive **or** no semantic query applies (e.g. the element has no visible text, no label, and no meaningful role). Hash-like opaque `data-qa` values (e.g. `"xB3mK9nP2rQ8sVwY"`) should be replaced with role/text/label queries whenever the source component has visible text or an accessible name.
2. Use `queryBy*` variants only for non-existence checks (for example, `expect(screen.queryByText(/error/i)).not.toBeInTheDocument()`).
3. Prefer case-insensitive regex for user-facing text assertions and queries (for example, `screen.getByText(/your text here/i)` and `screen.getByRole('button', { name: /save/i })`).
4. For user simulation, prefer `userEvent` over `fireEvent` when possible.
5. For empty DOM assertions, prefer `toBeEmptyDOMElement()` on a rendered `container` instead of Enzyme-style `isEmptyRender()).toBe(true)` checks.

---

## Custom Render Helpers (Reference Implementation)

When components need providers (Redux, Router, Intl, SWR, etc.), wrap them once in a shared helper. Below is a generic, drop-in implementation you can adapt to your stack.

```tsx
// test-utils/render.tsx
/* eslint-disable import/export */
import React from 'react';
import { queryByAttribute, render, screen } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { Provider } from 'react-redux';
import { MemoryRouter, Route } from 'react-router-dom';
import configureMockStore from 'redux-mock-store';
import thunk from 'redux-thunk';
import { SWRConfig } from 'swr';

const mockStore = configureMockStore([thunk]);
const getStore = (state: object = {}) => mockStore({ ...state });

export const WithDefaultProviders: React.FC = ({ children }) => (
  <IntlProvider locale="en" defaultLocale="en">
    {children}
  </IntlProvider>
);

const WithReduxProviders = (store: ReturnType<typeof getStore>) =>
  ({ children }: { children: React.ReactNode }) => (
    <WithDefaultProviders>
      <Provider store={store}>{children}</Provider>
    </WithDefaultProviders>
  );

const WithReduxAndRouterProviders = (store: ReturnType<typeof getStore>) =>
  ({ children }: { children: React.ReactNode }) => (
    <WithDefaultProviders>
      <Provider store={store}>
        <MemoryRouter>{children}</MemoryRouter>
      </Provider>
    </WithDefaultProviders>
  );

export function renderWithRedux(
  ui: React.ReactNode,
  { initialState = {}, store = getStore(initialState) } = {},
) {
  return { ...render(<>{ui}</>, { wrapper: WithReduxProviders(store) }), store };
}

export function renderWithReduxAndRouter(
  ui: React.ReactNode,
  { initialState = {}, store = getStore(initialState) } = {},
) {
  return {
    ...render(<>{ui}</>, { wrapper: WithReduxAndRouterProviders(store) }),
    store,
  };
}

export function renderWithRouter(ui: React.ReactNode) {
  return render(
    <MemoryRouter>
      <Route>{ui}</Route>
    </MemoryRouter>,
    { wrapper: WithDefaultProviders },
  );
}

export function renderWithSwrRedux(
  ui: React.ReactNode,
  { initialState = {}, store = getStore(initialState) } = {},
) {
  return renderWithRedux(
    <SWRConfig value={{ dedupingInterval: 0 }}>{ui}</SWRConfig>,
    { store },
  );
}

// Default render injects only the base providers (i18n in this example).
const customRender = (ui: React.ReactElement, options = {}) =>
  render(ui, { wrapper: WithDefaultProviders, ...options });

// --- Selector helpers (legacy fallbacks; prefer role/label/text queries) ---
export const queryById = (id: string, container: HTMLElement = document.body) =>
  queryByAttribute('id', container, id);

export const queryByQa = (qa: string, container: HTMLElement = document.body) =>
  queryByAttribute('data-qa', container, qa);

export const queryByClassName = (
  className: string,
  container: HTMLElement = document.body,
) => queryByAttribute('class', container, className);

export const getAllByAttribute = (
  attribute: string,
  container: HTMLElement = document.body,
  value?: string,
) => {
  const selector = value ? `[${attribute}="${value}"]` : `[${attribute}]`;
  return Array.from(container.querySelectorAll(selector));
};

// Re-export everything from RTL and override `render`.
export * from '@testing-library/react';
export { customRender as render, getStore, screen };
```

Drop only the helpers you need. Strip Redux / Router / SWR pieces if your project doesn't use them.

---

## Non-Negotiable Guardrails

1. **Test Intent** — Preserve original test intent exactly. Do not flip or weaken assertions.
2. **Test Case Names** — Preserve all `describe()` block names and `it()` descriptions exactly as they appear in the original test file. Test names communicate intent and are part of the test contract—do not rename, simplify, or consolidate them.
3. **Regression Recovery** — If a converted test fails, fix test setup/harness (providers, fixtures) before changing expected behavior.
4. **Selector Preservation** — If the original assertion targeted a class, preserve a class-based check during migration. Refactor to richer queries in a follow-up pass.
5. **Mock Cleanup** — `jest.clearAllMocks()` (or `mockReset`) in `beforeEach()` to avoid cross-test leakage.
6. **Production Code Off-Limits** — Do not change business logic as part of migration.
7. **Deterministic Tests** — Add explicit waits (`findBy*`, `waitFor`) and deterministic fixtures for async scenarios.
8. **Component Path Validation** — Even if the original Enzyme code only navigated to a component without an explicit `expect`, preserve that validation in RTL via container queries or mock-render assertions. Do not silently drop component existence checks.
9. **Scope Discipline** — Migrate test files only. Do not modify production source as a side effect.
10. **No Code Optimization** — Do not extract duplicate code, refactor into helper functions, or simplify test structure as part of migration. The goal is **line-by-line conversion**, not optimization. Reuse existing helpers if available, but do not create new ones. Keep diffs focused solely on Enzyme→RTL conversion.

---

## Workflow Summary

1. **Phase 1** — Assess complexity & dependencies.
2. **Phase 2** — Swap imports (Enzyme → RTL, add `userEvent`).
3. **Phase 3** — Walk the selector decision tree.
4. **Phase 4** — Per-test conversion (render, selectors, events, async). **No optimization or new helpers** — convert line-by-line, reuse existing helpers only.
5. **Phase 5** — Validate: run `verify.sh <file>` (ESLint, Prettier, Jest, TypeScript, Enzyme remnant grep) then manual intent review. _(For deeper validation, invoke the [`enzyme-to-rtl-migration-validation`](../enzyme-to-rtl-migration-validation/SKILL.md) skill on demand.)_
6. **Phase 6** — Repeat across the batch; keep diffs small and reviewable.
7. **Phase 7** — Once green, optionally tighten queries (class → role/label/text) in a follow-up pass.

---

**Key discipline**: This workflow prioritizes **line-by-line translation** over optimization. Extract new helpers or refactor test logic in a separate pass once all migrations are complete and tests are green.

---

## When to Escalate

- **Test intents conflict** — Can't migrate without changing business logic → consult test author.
- **Persistent flakiness** — Converted test randomly fails → add explicit waits and deterministic fixtures.
- **Mocking complexity** — Multiple interdependent mocks → plan a mock strategy before converting.
- **Custom helpers needed** — Existing patterns don't cover the selector type → extend your shared test-utils module.
