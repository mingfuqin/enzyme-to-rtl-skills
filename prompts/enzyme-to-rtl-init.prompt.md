---
name: enzyme-to-rtl-init
description: >
  Initialize the Enzyme → RTL migration for this project. Produces a focused snapshot:
  library versions, migration status counts (enzyme-only / mixed / rtl-incomplete / rtl-complete),
  custom render helpers, Enzyme adapter config, RTL testIdAttribute, and a risk-ordered file list.
  Also verifies or bootstraps the project instruction file and offers mock pattern analysis.
  Use at the start of every migration session to pick up context without repeated discovery work.
---

# Initialize: Enzyme → RTL Migration Project Overview

Follow the full workflow defined in `.github/skills/enzyme-to-rtl-migration/initialize-project.md`.

---

## Step 0: Try the Collector Script

```bash
bash .github/skills/enzyme-to-rtl-migration/collect-init-overview.sh --mode preview
```

**If the script runs successfully**, use its output as the concise overview and ask whether
to run `--mode full` for the complete report. Skip the manual steps below.

**If the script fails or is unavailable**, follow the manual workflow in
`.github/skills/enzyme-to-rtl-migration/initialize-project.md` (Steps 1–7).
Note the failure reason so it can be fixed.
