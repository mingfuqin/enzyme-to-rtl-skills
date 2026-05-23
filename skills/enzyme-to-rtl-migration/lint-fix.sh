#!/bin/bash

# lint-fix.sh - Format and lint transformed test files
# Usage: ./lint-fix.sh <file-path>
# Works anywhere - no config file dependencies

set -e

if [[ -z "$1" ]]; then
    echo "Usage: $0 <file-path>"
    exit 1
fi

FILE="$1"
[[ -f "$FILE" ]] || { echo "Error: File not found: $FILE"; exit 1; }

# Detect base indentation: find first indented line and count leading spaces
INDENT=$(awk '/^[[:space:]]+/ { match($0, /^[[:space:]]+/); print length(substr($0, RSTART, RLENGTH)); exit }' "$FILE")
INDENT=${INDENT:-2}  # default to 2 if no indented line found

npx eslint --fix \
  --rule "indent: off"  "$FILE" 2>/dev/null || true

npx prettier --write --tab-width "$INDENT" --semi --single-quote --trailing-comma all "$FILE" 2>/dev/null

echo "✓ Formatted: $FILE (indent: $INDENT spaces)"

