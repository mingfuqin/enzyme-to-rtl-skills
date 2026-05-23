---
name: rtl-batch
description: Process Enzyme-to-RTL migration batches from the migration queue, migrate in chunks of 3–5 files using the single-file migration workflow
tools: ['runSubagent']
agents: ['rtl-migrate']
---

# Enzyme-to-RTL Batch Migration

## Step 1: Load the migration queue

Read `.github/instructions/enzyme-to-rtl-migration-queue.md`.

If it does not exist, stop and tell the user:
> "No migration queue found. Please run `/rtl-init` first to initialize the project and generate the migration queue."

Use the unchecked entries (`- [ ]`) as the work items to process, in the order they appear in the queue.

## Step 2: Load project instruction file

Load `.github/instructions/enzyme-to-rtl-migration.instructions.md` if present; apply its rules throughout the migration.

## Step 3: Ask user which files to process

Present the unchecked files from the queue (grouped by risk tier as written) and ask the user which files or tier to start with. User controls the scope.

## Step 4: Execute in chunks of 3–5 files

For each chunk:

1. Invoke `#runSubagent rtl-migrate` for each file in the chunk, passing the file path as the argument.
2. Collect the summary returned by the subagent: file path + pass/fail + any errors. Do not re-send full file contents
   unless a specific mismatch requires debugging.
3. After a file passes Phase 5 validation, mark its entry checked (`- [x]`) in the queue file.
4. After all files in the chunk pass, move to the next chunk.

**Batch size rule**: process 3–5 files per chunk. For high-risk files, treat each chunk
of 5–7 tests within a file as its own unit.

## Step 5: Batch summary report

After all chunks complete, return a summary table:

| File | Risk | Status | Notes |
|------|------|--------|-------|

Followed by a **Remaining issues** section listing any file that did not reach full Phase 5
pass, with the blocking layer and recommended next step.

> To validate already-migrated files (assert quality, Enzyme remnant check, pre-PR), use the
> `rtl-validate-batch` prompt instead.
