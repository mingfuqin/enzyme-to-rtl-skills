#!/bin/bash

# lint-fix.sh - Format and lint transformed test files
# Usage: ./lint-fix.sh <file-path>

set -e

if [[ -z "$1" ]]; then
    echo "Usage: $0 <file-path>"
    exit 1
fi

FILE="$1"
[[ -f "$FILE" ]] || { echo "Error: File not found: $FILE"; exit 1; }

npx eslint -c .eslintrc.js --no-eslintrc --fix --no-error-on-unmatched-pattern "$FILE" 2>/dev/null || true

npx eslint --fix \
  --rule "indent: off"  "$FILE" 2>/dev/null || true

npx prettier --write --tab-width "$INDENT" --semi --single-quote --trailing-comma all "$FILE" 2>/dev/null

echo "✓ Formatted: $FILE (indent: $INDENT spaces)"

