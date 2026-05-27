#!/bin/bash
# uninstall-from-project.sh
#
# Uninstalls enzyme-to-rtl skills, prompts, and agents from a target project.
# 
# This script removes:
#   - Skill directories (enzyme-to-rtl-migration, enzyme-to-rtl-migration-validation)
#   - Prompt files (.prompt.md)
#   - Agent files (.agent.md)
#   - Instructions directory (optional — can preserve if it contains user data)
#
# Usage:
#   bash scripts/uninstall-from-project.sh [options]
#
# Options:
#   --target <dir>            Root directory of the target project
#                             (default: current working directory)
#   --skills-path <path>      Where skill files are installed, relative to target
#                             (default: .github/skills)
#   --prompts-path <path>     Where prompt files are installed, relative to target
#                             (default: .github/prompts)
#   --agents-path <path>      Where agent files are installed, relative to target
#                             (default: .github/agents)
#   --instructions-path <path>  Where instruction/queue files are stored,
#                             relative to target (default: .github/instructions)
#   --keep-instructions       Preserve the instructions directory (contains generated files)
#   -y, --yes                 Skip confirmation prompts (auto-remove)
#   -h, --help                Show this help message
#
# Example — uninstall from current directory:
#   bash scripts/uninstall-from-project.sh
#
# Example — uninstall from a sibling project, keeping instructions:
#   bash scripts/uninstall-from-project.sh --target ../my-project --keep-instructions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
TARGET_DIR="$(pwd)"
SKILLS_PATH=".github/skills"
PROMPTS_PATH=".github/prompts"
AGENTS_PATH=".github/agents"
INSTRUCTIONS_PATH=".github/instructions"
KEEP_INSTRUCTIONS=false
AUTO_YES=false

# ── Parse arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)            TARGET_DIR="$2";        shift 2 ;;
    --skills-path)       SKILLS_PATH="$2";       shift 2 ;;
    --prompts-path)      PROMPTS_PATH="$2";      shift 2 ;;
    --agents-path)       AGENTS_PATH="$2";       shift 2 ;;
    --instructions-path) INSTRUCTIONS_PATH="$2"; shift 2 ;;
    --keep-instructions) KEEP_INSTRUCTIONS=true; shift ;;
    -y|--yes)            AUTO_YES=true;          shift ;;
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

echo "Uninstalling enzyme-to-rtl skills from: $TARGET_DIR"
echo "  Skills       ← $SKILLS_PATH/"
echo "  Prompts      ← $PROMPTS_PATH/"
echo "  Agents       ← $AGENTS_PATH/"
if [[ "$KEEP_INSTRUCTIONS" == true ]]; then
  echo "  Instructions — $INSTRUCTIONS_PATH/  (preserving)"
else
  echo "  Instructions ← $INSTRUCTIONS_PATH/"
fi
echo ""

# ── Helper: confirm before removing an item ────────────────────────────────────
# Usage: confirm_remove <path> <label>
# Returns 0 to proceed, exits 1 if user declines.
confirm_remove() {
  local PATH_TO_REMOVE="$1"
  local LABEL="$2"

  if [[ ! -e "$PATH_TO_REMOVE" && ! -L "$PATH_TO_REMOVE" ]]; then
    echo "  ✓  $LABEL (not present)"
    return 0  # nothing there, proceed
  fi

  if [[ -L "$PATH_TO_REMOVE" ]]; then
    echo "  ⚠  symlink:  $LABEL  →  $(readlink "$PATH_TO_REMOVE")"
  elif [[ -d "$PATH_TO_REMOVE" ]]; then
    echo "  ⚠  directory: $LABEL"
  else
    echo "  ⚠  file:     $LABEL"
  fi

  if [[ "$AUTO_YES" == true ]]; then
    rm -rf "$PATH_TO_REMOVE"
    echo "     → removed"
    return 0
  fi

  printf "     Remove? [y/N] "
  read -r REPLY </dev/tty
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    rm -rf "$PATH_TO_REMOVE"
    echo "     → removed"
    return 0
  else
    echo "     → skipped"
    return 1
  fi
}

# ── Remove skill directories ──────────────────────────────────────────────────
echo "Skills:"
for SKILL_NAME in enzyme-to-rtl-migration enzyme-to-rtl-migration-validation; do
  DEST="$DEST_SKILLS/$SKILL_NAME"
  confirm_remove "$DEST" "skills/$SKILL_NAME"
done

# ── Remove prompt files (.prompt.md) ───────────────────────────────────────────
echo ""
echo "Prompts:"
for PROMPT_NAME in rtl-init.prompt.md; do
  DEST="$DEST_PROMPTS/$PROMPT_NAME"
  confirm_remove "$DEST" "prompts/$PROMPT_NAME"
done

# ── Remove agent files (.agent.md) ────────────────────────────────────────────
echo ""
echo "Agents:"
for AGENT_NAME in rtl-batch.agent.md rtl-migrate.agent.md rtl-validate-batch.agent.md rtl-validate.agent.md; do
  DEST="$DEST_AGENTS/$AGENT_NAME"
  confirm_remove "$DEST" "agents/$AGENT_NAME"
done

# ── Remove empty parent directories ────────────────────────────────────────────
echo ""
echo "Cleanup:"
for DIR in "$DEST_AGENTS" "$DEST_PROMPTS" "$DEST_SKILLS"; do
  if [[ -d "$DIR" && -z "$(ls -A "$DIR" 2>/dev/null)" ]]; then
    confirm_remove "$DIR" "$(basename "$DIR") directory (empty)"
  fi
done

# ── Handle instructions directory ──────────────────────────────────────────────
if [[ "$KEEP_INSTRUCTIONS" == false ]]; then
  echo ""
  echo "Instructions:"
  confirm_remove "$DEST_INSTRUCTIONS" "instructions directory"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Uninstallation complete."
echo ""
if [[ "$KEEP_INSTRUCTIONS" == true ]]; then
  echo "Note: Instructions directory preserved at $INSTRUCTIONS_PATH/"
  echo "      (contains any generated migration queue and instruction files)"
fi
