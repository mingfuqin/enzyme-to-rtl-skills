#!/bin/bash
# install-to-project.sh
#
# Installs enzyme-to-rtl skills, prompts, and agents into a target project so VS Code
# Copilot can run the migration workflow out of the box.
#
# By default creates symlinks so edits in this repo are reflected immediately.
# Use --copy to copy files instead (required when using custom --skills-path or
# --instructions-path, because path-patching does not work through symlinks).
#
# Usage:
#   bash scripts/install-to-project.sh [options]
#
# Options:
#   --target <dir>            Root directory of the target project
#                             (default: current working directory)
#   --skills-path <path>      Where to install skill files, relative to target
#                             (default: .github/skills)
#   --prompts-path <path>     Where to install prompt files (.prompt.md), relative to target
#                             (default: .github/prompts)
#   --agents-path <path>      Where to install agent files (.agent.md), relative to target
#                             (default: .github/agents)
#   --instructions-path <path>  Where generated instruction/queue files will land,
#                             relative to target (default: .github/instructions)
#   --copy                    Copy files instead of symlinking
#   -y, --yes                 Skip confirmation prompts (auto-replace existing items)
#   -h, --help                Show this help message
#
# After installation, users start with:
#   /rtl-init           — prompt: scan the project and build the migration queue
#   @rtl-batch          — agent:  migrate files in risk-ordered batches
#   @rtl-migrate <file> — agent:  migrate a single file
#   @rtl-validate-batch — agent:  validate all changed files
#   @rtl-validate <file> — agent: run 5-layer validation on a single file
#
# Example — symlink into a sibling project (default):
#   bash scripts/install-to-project.sh --target ../my-project
#
# Example — copy with a custom skills path:
#   bash scripts/install-to-project.sh --target ../my-project \
#     --copy --skills-path .agents/skills

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
TARGET_DIR="$(pwd)"
SKILLS_PATH=".github/skills"
PROMPTS_PATH=".github/prompts"
AGENTS_PATH=".github/agents"
INSTRUCTIONS_PATH=".github/instructions"
USE_COPY=false
AUTO_YES=false

# ── Parse arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)            TARGET_DIR="$2";        shift 2 ;;
    --skills-path)       SKILLS_PATH="$2";       shift 2 ;;
    --prompts-path)      PROMPTS_PATH="$2";      shift 2 ;;
    --agents-path)       AGENTS_PATH="$2";       shift 2 ;;
    --instructions-path) INSTRUCTIONS_PATH="$2"; shift 2 ;;
    --copy)              USE_COPY=true;           shift ;;
    -y|--yes)            AUTO_YES=true;           shift ;;
    -h|--help)
      awk '/^set -/{exit} /^#[^!]/{sub(/^# ?/,""); print}' "$0"
      exit 0
      ;;
    *) echo "Error: unknown option: $1" >&2; exit 1 ;;
  esac
done

TARGET_DIR="$(realpath "$TARGET_DIR")"
DEST_SKILLS="$TARGET_DIR/$SKILLS_PATH"
DEST_PROMPTS="$TARGET_DIR/$PROMPTS_PATH"
DEST_AGENTS="$TARGET_DIR/$AGENTS_PATH"
DEST_INSTRUCTIONS="$TARGET_DIR/$INSTRUCTIONS_PATH"

# ── Validate target ────────────────────────────────────────────────────────────
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

# ── Enforce --copy for non-default paths ──────────────────────────────────────
DEFAULT_SKILLS_PATH=".github/skills"
DEFAULT_AGENTS_PATH=".github/agents"
DEFAULT_INSTRUCTIONS_PATH=".github/instructions"

if [[ "$USE_COPY" == false ]] && \
   [[ "$SKILLS_PATH" != "$DEFAULT_SKILLS_PATH" || "$AGENTS_PATH" != "$DEFAULT_AGENTS_PATH" || "$INSTRUCTIONS_PATH" != "$DEFAULT_INSTRUCTIONS_PATH" ]]; then
  echo "Error: --skills-path or --instructions-path is non-default." >&2
  echo "       Path-patching requires --copy (symlinks point back to source)." >&2
  echo "       Re-run with --copy to proceed." >&2
  exit 1
fi

echo "Installing enzyme-to-rtl skills into: $TARGET_DIR"
echo "  Mode:        $([ "$USE_COPY" == true ] && echo 'copy' || echo 'symlink')"
echo "  Skills       → $SKILLS_PATH/"
echo "  Prompts      → $PROMPTS_PATH/"
echo "  Agents       → $AGENTS_PATH/"
echo "  Instructions → $INSTRUCTIONS_PATH/  (generated files land here at runtime)"
echo ""

# ── Helper: confirm before removing an existing path ─────────────────────────
# Usage: confirm_remove <dest> <label>
# Returns 0 to proceed, exits 1 if user declines.
confirm_remove() {
  local DEST="$1"
  local LABEL="$2"

  if [[ ! -e "$DEST" && ! -L "$DEST" ]]; then
    return 0  # nothing there, proceed
  fi

  if [[ -L "$DEST" ]]; then
    echo "  ⚠  symlink already exists: $DEST  →  $(readlink "$DEST")"
  elif [[ -d "$DEST" ]]; then
    echo "  ⚠  directory already exists: $DEST"
  else
    echo "  ⚠  file already exists: $DEST"
  fi

  if [[ "$AUTO_YES" == true ]]; then
    rm -rf "$DEST"
    return 0
  fi

  printf "     Replace with $LABEL? [y/N] "
  read -r REPLY </dev/tty
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    rm -rf "$DEST"
    return 0
  else
    echo "     Skipped."
    return 1
  fi
}

# ── Helper: install one item (symlink or copy) ────────────────────────────────
# Usage: install_item <src> <dest> <label>
install_item() {
  local SRC="$1"
  local DEST="$2"
  local LABEL="$3"

  confirm_remove "$DEST" "$LABEL" || return 0

  if [[ "$USE_COPY" == true ]]; then
    if [[ -d "$SRC" ]]; then
      cp -R "$SRC" "$DEST"
      find "$DEST" -name "*.sh" -exec chmod +x {} \;
    else
      cp "$SRC" "$DEST"
    fi
  else
    ln -s "$SRC" "$DEST"
  fi

  echo "  ✓  $LABEL"
}

# ── Install skill directories ─────────────────────────────────────────────────
mkdir -p "$DEST_SKILLS"
for SKILL_NAME in enzyme-to-rtl-migration enzyme-to-rtl-migration-validation; do
  SRC="$REPO_ROOT/skills/$SKILL_NAME"
  DEST="$DEST_SKILLS/$SKILL_NAME"
  install_item "$SRC" "$DEST" "skills/$SKILL_NAME  →  $SKILLS_PATH/$SKILL_NAME"
done

# ── Install prompt files (.prompt.md) ────────────────────────────────────────
mkdir -p "$DEST_PROMPTS"
for SRC in "$REPO_ROOT"/prompts/rtl-*.prompt.md; do
  [[ -f "$SRC" ]] || continue
  BASENAME="$(basename "$SRC")"
  install_item "$SRC" "$DEST_PROMPTS/$BASENAME" "prompts/$BASENAME  →  $PROMPTS_PATH/$BASENAME"
done

# ── Install agent files (.agent.md) ──────────────────────────────────────────
mkdir -p "$DEST_AGENTS"
for SRC in "$REPO_ROOT"/prompts/rtl-*.agent.md; do
  [[ -f "$SRC" ]] || continue
  BASENAME="$(basename "$SRC")"
  install_item "$SRC" "$DEST_AGENTS/$BASENAME" "agents/$BASENAME  →  $AGENTS_PATH/$BASENAME"
done

# ── Create instructions directory (generated files land here) ─────────────────
mkdir -p "$DEST_INSTRUCTIONS"
echo "  ✓  $INSTRUCTIONS_PATH/  ready (init will write instruction and queue files here)"

# ── Patch path references for non-default paths (copy mode only) ──────────────
if [[ "$USE_COPY" == true ]] && \
   [[ "$SKILLS_PATH" != "$DEFAULT_SKILLS_PATH" || "$AGENTS_PATH" != "$DEFAULT_AGENTS_PATH" || "$INSTRUCTIONS_PATH" != "$DEFAULT_INSTRUCTIONS_PATH" ]]; then
  echo ""
  echo "Patching path references in copied files..."

  find "$DEST_SKILLS" "$DEST_PROMPTS" "$DEST_AGENTS" -name "*.md" | while read -r FILE; do
    CHANGED=false
    if [[ "$SKILLS_PATH" != "$DEFAULT_SKILLS_PATH" ]]; then
      sed -i.bak "s|${DEFAULT_SKILLS_PATH}|${SKILLS_PATH}|g" "$FILE"
      CHANGED=true
    fi
    if [[ "$AGENTS_PATH" != "$DEFAULT_AGENTS_PATH" ]]; then
      sed -i.bak "s|${DEFAULT_AGENTS_PATH}|${AGENTS_PATH}|g" "$FILE"
      CHANGED=true
    fi
    if [[ "$INSTRUCTIONS_PATH" != "$DEFAULT_INSTRUCTIONS_PATH" ]]; then
      sed -i.bak "s|${DEFAULT_INSTRUCTIONS_PATH}|${INSTRUCTIONS_PATH}|g" "$FILE"
      CHANGED=true
    fi
    if $CHANGED; then
      rm -f "${FILE}.bak"
      echo "  ✓  patched: $(basename "$FILE")"
    fi
  done
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Installation complete."
echo ""
echo "Next steps:"
echo "  1. Open VS Code in $TARGET_DIR"
echo "  2. Run /rtl-init in Copilot Chat to scan the project and"
echo "     generate the risk-ordered migration queue"
echo "  3. Run @rtl-batch to start migrating in batches,"
echo "     or @rtl-migrate <file> to migrate one file at a time"
echo "  4. Run @rtl-validate-batch to validate all changed files,"
echo "     or @rtl-validate <file> to validate a single file"
echo ""
if [[ "$USE_COPY" == false ]]; then
  echo "Tip: files are symlinked — edits in this repo are reflected immediately."
  echo "     Re-run with --copy to get standalone copies instead."
else
  echo "Tip: if your project uses a custom test root or package layout, edit:"
  echo "  $DEST_SKILLS/enzyme-to-rtl-migration/initialize-project.md"
fi
