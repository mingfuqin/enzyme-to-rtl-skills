#!/bin/bash

# Enzyme → RTL Migration Init Overview Collector
# Gathers migration-relevant facts: versions, status counts, helpers, pipeline info

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"

# Parse --mode <value> or positional first argument
MODE="full"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-full}"; shift 2 ;;
    preview|full) MODE="$1"; shift ;;
    *) shift ;;
  esac
done

# Color codes for output
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Helpers
red() { echo -e "${BOLD}❌ $*${RESET}" >&2; }
green() { echo -e "${BOLD}✓ $*${RESET}"; }
info() { echo -e "${DIM}→ $*${RESET}"; }
header() { echo -e "\n${BOLD}## $*${RESET}"; }
subheader() { echo -e "\n${BOLD}### $*${RESET}"; }

# Convert absolute path to relative path from REPO_ROOT
to_rel_path() {
  local abs_path="$1"
  python3 -c "import os; print(os.path.relpath('$abs_path', '$REPO_ROOT'))" 2>/dev/null || echo "$abs_path"
}

# Check if file has enzyme import (direct enzyme import OR intl-enzyme-helper)
check_enzyme_import() {
  grep -qE "from ['\"]enzyme['\"]|from ['\"][^'\"]*intl-enzyme-helper['\"]" "$1" 2>/dev/null
}

# Check if file has RTL import
check_rtl_import() {
  grep -q "@testing-library/react" "$1" 2>/dev/null
}

# Collect versions from package.json files
collect_versions() {
  local versions_output=""
  
  # Function to extract version from a single package.json
  extract_dep_version() {
    local pkg_file="$1"
    local dep="$2"
    
    if [[ ! -f "$pkg_file" ]]; then
      return
    fi
    
    local version
    version=$(grep -E "\"$dep\":[[:space:]]*\"[^\"]+\"" "$pkg_file" | head -1 | sed -E "s|.*\"${dep}\":[[:space:]]*\"([^\"]+)\".*|\1|")
    
    if [[ -n "$version" ]]; then
      local rel_pkg
      rel_pkg=$(to_rel_path "$pkg_file")
      echo "$dep|$version|$rel_pkg"
    fi
  }
  
  # Collect from root and all workspace package.json files
  local pkg_files=("$REPO_ROOT/package.json")
  if [[ -d "$REPO_ROOT/workspaces" ]]; then
    while IFS= read -r -d '' pkg; do
      pkg_files+=("$pkg")
    done < <(find "$REPO_ROOT/workspaces" -maxdepth 2 -name "package.json" -print0)
  fi
  
  local deps=(
    "enzyme"
    "@testing-library/react"
    "@testing-library/user-event"
    "@testing-library/jest-dom"
    "react"
    "react-dom"
    "jest"
    "@types/enzyme"
  )
  
  header "Library Versions"
  echo "| Dependency | Version | Source |"
  echo "|---|---|---|"
  
  for dep in "${deps[@]}"; do
    local found=0
    for pkg_file in "${pkg_files[@]}"; do
      local result
      result=$(extract_dep_version "$pkg_file" "$dep" || true)
      if [[ -n "$result" ]]; then
        local version
        local source
        version=$(echo "$result" | cut -d'|' -f2)
        source=$(echo "$result" | cut -d'|' -f3)
        echo "| $dep | $version | $source |"
        found=1
        break
      fi
    done
    if [[ $found -eq 0 ]]; then
      echo "| $dep | not found | - |"
    fi
  done
  
  # Check for enzyme adapters
  info "Checking for enzyme adapters..."
  for pkg_file in "${pkg_files[@]}"; do
    if grep -qE "enzyme-adapter-react-" "$pkg_file" 2>/dev/null; then
      local adapters
      adapters=$(grep -oE "\"(enzyme-adapter-react-[^\"]+|@wojtekmaj/enzyme-adapter-react-[^\"]*)\":[[:space:]]*\"[^\"]+\"" "$pkg_file" | sed -E 's|"([^"]+)":[[:space:]]*"([^"]+)"|\1@\2|' | tr '\n' ', ')
      if [[ -n "$adapters" ]]; then
        echo "| Enzyme adapters | ${adapters%, } | $(python3 -c "import os; print(os.path.relpath('$pkg_file', '$REPO_ROOT'))" 2>/dev/null || echo "$pkg_file") |"
      fi
    fi
  done
}

# Classify test files and count by status
count_test_statuses() {
  local enzyme_only=0
  local mixed=0
  local rtl_incomplete=0
  local rtl_complete=0
  local total=0
  local mount_files=0
  local shallow_files=0
  
  # Find all test files
  local test_files
  test_files=$(find "$REPO_ROOT" -type f \( -name "*.test.js" -o -name "*.test.ts" -o -name "*.test.jsx" -o -name "*.test.tsx" -o -name "*.spec.js" -o -name "*.spec.ts" \) ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/coverage/*" ! -path "*/dist/*" 2>/dev/null || true)
  
  while IFS= read -r test_file; do
    [[ -z "$test_file" ]] && continue
    total=$((total + 1))
    
    local has_enzyme_import=0
    local has_rtl_import=0
    local has_incomplete=0
    
    check_enzyme_import "$test_file" && has_enzyme_import=1
    check_rtl_import "$test_file" && has_rtl_import=1
    
    if grep -qE "it\.skip[[:space:]]*\(|it\.todo[[:space:]]*\(|TODO|FIXME" "$test_file" 2>/dev/null; then
      has_incomplete=1
    fi
    
    if grep -q "mount[[:space:]]*(" "$test_file" 2>/dev/null; then
      mount_files=$((mount_files + 1))
    fi
    
    if grep -q "shallow[[:space:]]*(" "$test_file" 2>/dev/null; then
      shallow_files=$((shallow_files + 1))
    fi
    
    if [[ $has_enzyme_import -eq 1 && $has_rtl_import -eq 1 ]]; then
      mixed=$((mixed + 1))
    elif [[ $has_enzyme_import -eq 1 ]]; then
      enzyme_only=$((enzyme_only + 1))
    elif [[ $has_rtl_import -eq 1 && $has_incomplete -eq 1 ]]; then
      rtl_incomplete=$((rtl_incomplete + 1))
    elif [[ $has_rtl_import -eq 1 ]]; then
      rtl_complete=$((rtl_complete + 1))
    fi
  done <<< "$test_files"
  
  header "Migration Status"
  echo "| Status | Count |"
  echo "|---|---|"
  echo "| enzyme-only | $enzyme_only |"
  echo "| mixed | $mixed |"
  echo "| rtl-incomplete | $rtl_incomplete |"
  echo "| rtl-complete | $rtl_complete |"
  echo "| Total | $total |"
  
  local remaining=$((enzyme_only + mixed + rtl_incomplete))
  echo ""
  echo "Remaining work: **$remaining files** (enzyme-only + mixed + rtl-incomplete)"
  echo ""
  echo "Usage patterns:"
  echo "- Files using \`mount()\`: $mount_files"
  echo "- Files using \`shallow()\`: $shallow_files"
}

# Find custom render helpers (searches common locations)
find_helpers() {
  header "Custom Render Helpers"

  # Search common RTL helper locations and file names
  local candidates
  candidates=$(find "$REPO_ROOT" -type f \
    \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
    \( -name "react-testing-library.*" -o -name "test-utils.*" -o -name "testUtils.*" \
       -o -name "renderWithProviders.*" \
       -o -path "*/test-helpers/*" -o -path "*/test-utils/*" \
       -o -path "*/__test-utils__/*" -o -path "*/testUtils/*" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" ! -path "*/coverage/*" \
    2>/dev/null | sort -u || true)

  # Keep only files that actually import @testing-library/react
  local rtl_helpers=()
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if grep -q "@testing-library/react" "$f" 2>/dev/null; then
      rtl_helpers+=("$f")
    fi
  done <<< "$candidates"

  if [[ ${#rtl_helpers[@]} -eq 0 ]]; then
    echo "- none found (searched test-helpers/, test-utils/, __test-utils__/, testUtils/ and common file names)"
    return
  fi

  for helper_file in "${rtl_helpers[@]}"; do
    local rel_path
    rel_path=$(to_rel_path "$helper_file")
    info "Found: $rel_path"

    local exports
    exports=$(grep -oE "export[[:space:]]+(function|const)[[:space:]]+([A-Za-z0-9_]+)" "$helper_file" \
      | awk '{print $NF}' | sort -u)

    if [[ -z "$exports" ]]; then
      echo "- $rel_path: no exports detected"
      continue
    fi

    while IFS= read -r helper; do
      [[ -z "$helper" ]] && continue
      local providers=()
      if grep -q "IntlProvider" "$helper_file" 2>/dev/null; then providers+=("IntlProvider"); fi
      if echo "$helper" | grep -qi "redux";  then providers+=("redux Provider"); fi
      if echo "$helper" | grep -qi "router"; then providers+=("MemoryRouter/Route"); fi
      if echo "$helper" | grep -qi "swr";    then providers+=("SWRConfig"); fi
      if echo "$helper" | grep -qi "theme";  then providers+=("ThemeProvider"); fi
      local provider_str=""
      if [[ ${#providers[@]} -gt 0 ]]; then provider_str="${providers[*]}"; fi
      echo "- \`$helper\` — ${provider_str:-(default providers)}"
    done <<< "$exports"
  done
}

# Collect Jest and test pipeline facts (discovers configs dynamically)
collect_pipeline_facts() {
  header "Test Pipeline & Jest Configuration"

  # Discover jest config files up to depth 3
  local jest_configs
  jest_configs=$(find "$REPO_ROOT" -maxdepth 3 \
    \( -name "jest.config.js" -o -name "jest.config.ts" \
       -o -name "jest.config.mjs" -o -name "jest.config.cjs" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" \
    2>/dev/null | sort || true)

  if [[ -z "$jest_configs" ]]; then
    echo "- No jest.config.* found"
  else
    while IFS= read -r jest_config; do
      [[ -z "$jest_config" ]] && continue
      local rel_config config_dir config_pkg
      rel_config=$(to_rel_path "$jest_config")
      config_dir="$(dirname "$jest_config")"
      config_pkg="$config_dir/package.json"

      subheader "Jest Config: $rel_config"

      # Test scripts from adjacent package.json
      if [[ -f "$config_pkg" ]]; then
        local scripts
        scripts=$(grep -E '"(test|jest|jest:ci|test:tz|coverage)":' "$config_pkg" \
          | sed 's/.*"\([^"]*\)":[[:space:]]*"\([^"]*\)".*/- `\1`: \2/' || true)
        if [[ -n "$scripts" ]]; then
          echo "Test scripts:"
          echo "$scripts"
        fi
      fi

      # Key Jest settings
      if grep -q 'preset:' "$jest_config" 2>/dev/null; then
        local preset
        preset=$(grep -oE "preset:[[:space:]]*['\"]([^'\"]+)['\"]" "$jest_config" \
          | head -1 | sed -E "s|preset:[[:space:]]*['\"]([^'\"]+)['\"]|\1|")
        [[ -n "$preset" ]] && echo "- Preset: $preset"
      fi
      if grep -q 'testEnvironment:' "$jest_config" 2>/dev/null; then
        local env
        env=$(grep -oE "testEnvironment:[[:space:]]*['\"]([^'\"]+)['\"]" "$jest_config" \
          | head -1 | sed -E "s|testEnvironment:[[:space:]]*['\"]([^'\"]+)['\"]|\1|")
        [[ -n "$env" ]] && echo "- Test environment: $env"
      fi
      if grep -q 'maxWorkers:' "$jest_config" 2>/dev/null; then
        local workers
        workers=$(grep -oE "maxWorkers:[[:space:]]*['\"]?([^'\", ]+)" "$jest_config" \
          | head -1 | sed -E "s|maxWorkers:[[:space:]]*['\"]?||")
        [[ -n "$workers" ]] && echo "- Max workers: $workers"
      fi
      if grep -q 'setupFilesAfterEnv:' "$jest_config" 2>/dev/null; then
        echo "- setupFilesAfterEnv: configured"
      fi
      if grep -q 'SEGMENTS' "$jest_config" 2>/dev/null; then
        local segments
        segments=$(grep -oE "SEGMENTS[^=]*=[[:space:]]*\{[^}]*\}" "$jest_config" \
          | grep -oE "[0-9]:" | cut -d: -f1 | sort -u | tr '\n' ', ' | sed 's/,$//')
        [[ -n "$segments" ]] && echo "- Supported SEGMENT totals: $segments"
      fi
    done <<< "$jest_configs"
  fi

  # Find setup files for Enzyme adapter and testIdAttribute
  subheader "Enzyme & RTL Setup"
  local setup_files
  setup_files=$(find "$REPO_ROOT" -maxdepth 4 \
    \( -name "setup.jest.*" -o -name "setupTests.*" -o -name "jest.setup.*" \
       -o -name "setup.test.*" -o -name "setupFilesAfterEnv.*" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/dist/*" \
    2>/dev/null | sort || true)

  local found_setup=false
  while IFS= read -r setup_file; do
    [[ -z "$setup_file" ]] && continue
    found_setup=true
    local rel_setup
    rel_setup=$(to_rel_path "$setup_file")

    if grep -q "enzyme-adapter" "$setup_file" 2>/dev/null; then
      local adapter
      adapter=$(grep -oE "from ['\"]([^'\"]*enzyme-adapter[^'\"]*)['\"]" "$setup_file" \
        | sed -E "s|from ['\"]([^'\"]+)['\"]|\1|" | head -1)
      [[ -n "$adapter" ]] && echo "- Enzyme adapter: \`$adapter\` (from $rel_setup)"
    fi

    if grep -q "testIdAttribute" "$setup_file" 2>/dev/null; then
      local testIdAttr
      testIdAttr=$(grep -oE "testIdAttribute:[[:space:]]*['\"]([^'\"]+)['\"]" "$setup_file" \
        | sed -E "s|testIdAttribute:[[:space:]]*['\"]([^'\"]+)['\"]|\1|" | head -1)
      if [[ -n "$testIdAttr" ]]; then
        if [[ "$testIdAttr" == "data-testid" ]]; then
          echo "- RTL testIdAttribute: \`data-testid\` (RTL default, from $rel_setup)"
        else
          echo "- RTL testIdAttribute: **\`$testIdAttr\`** ⚠ non-standard — use \`$testIdAttr\` on all elements and mock stubs, never \`data-testid\` (from $rel_setup)"
        fi
      fi
    fi

    if grep -q "server.listen()" "$setup_file" 2>/dev/null; then
      echo "- MSW mock server lifecycle: enabled (from $rel_setup)"
    fi
  done <<< "$setup_files"

  if [[ "$found_setup" == "false" ]]; then
    echo "- No setup files found (searched: setup.jest.*, setupTests.*, jest.setup.*)"
  fi
}

# Find risk-ordered file list (all enzyme-only + mixed, sorted low → high)
find_risk_ordered_files() {
  header "Risk-Ordered File List (enzyme-only + mixed)"

  local test_files
  test_files=$(find "$REPO_ROOT" -type f \
    \( -name "*.test.js" -o -name "*.test.ts" -o -name "*.test.jsx" -o -name "*.test.tsx" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/coverage/*" ! -path "*/dist/*" \
    2>/dev/null || true)

  local temp_file
  temp_file=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '$temp_file'" RETURN

  while IFS= read -r test_file; do
    [[ -z "$test_file" ]] && continue

    local has_enzyme_import=0 has_rtl_import=0
    check_enzyme_import "$test_file" && has_enzyme_import=1
    check_rtl_import "$test_file" && has_rtl_import=1
    [[ $has_enzyme_import -eq 0 ]] && continue

    local line_count test_count tier rel_path status
    line_count=$(wc -l < "$test_file")
    test_count=$(grep -c -E "it\(|test\(" "$test_file" || echo 0)
    tier="low"
    if   (( line_count > 300 || test_count > 15 )); then tier="high"
    elif (( line_count >= 100 || test_count >= 5 )); then tier="medium"
    fi

    rel_path=$(to_rel_path "$test_file")
    status="enzyme-only"
    [[ $has_rtl_import -eq 1 ]] && status="mixed"
    echo "$tier|$line_count|$test_count|$rel_path|$status" >> "$temp_file"
  done <<< "$test_files"

  # Sort low → medium → high; within each tier ascending by line count (easy wins first)
  local low medium high
  low=$(grep    "^low|"    "$temp_file" | sort -t'|' -k2 -n || true)
  medium=$(grep "^medium|" "$temp_file" | sort -t'|' -k2 -n || true)
  high=$(grep   "^high|"   "$temp_file" | sort -t'|' -k2 -n || true)

  if [[ -n "$low" ]]; then
    subheader "Low Risk (< 100 lines, < 5 tests)"
    echo "$low" | while IFS='|' read -r _ lines tests path status; do
      echo "- $path ($status, $lines lines, $tests tests)"
    done
  fi
  if [[ -n "$medium" ]]; then
    subheader "Medium Risk (100–300 lines or 5–15 tests)"
    echo "$medium" | while IFS='|' read -r _ lines tests path status; do
      echo "- $path ($status, $lines lines, $tests tests)"
    done
  fi
  if [[ -n "$high" ]]; then
    subheader "High Risk (> 300 lines or > 15 tests)"
    echo "$high" | while IFS='|' read -r _ lines tests path status; do
      echo "- $path ($status, $lines lines, $tests tests)"
    done
  fi

  # Write queue file in full mode
  if [[ "$MODE" == "full" ]]; then
    write_queue_file "$temp_file"
  fi
}

# Emit one tier section for the migration queue
emit_tier() {
  local tier_data="$1"
  local tier_label="$2"
  local existing_checked="$3"
  [[ -z "$(echo "$tier_data" | grep -v '^$' || true)" ]] && return
  echo "## $tier_label"
  echo ""
  while IFS='|' read -r _ lines tests path status; do
    [[ -z "$path" ]] && continue
    local checkbox="- [ ]"
    if echo "$existing_checked" | grep -qF "$path" 2>/dev/null; then checkbox="- [x]"; fi
    echo "$checkbox \`$path\` — $status, $lines lines, $tests tests"
  done <<< "$tier_data"
  echo ""
}

# Write .github/instructions/enzyme-to-rtl-migration-queue.md
write_queue_file() {
  local data_file="$1"
  local queue_dir="$REPO_ROOT/.github/instructions"
  local queue_file="$queue_dir/enzyme-to-rtl-migration-queue.md"

  mkdir -p "$queue_dir"

  # Preserve any already-checked entries from an existing queue
  local existing_checked=""
  local checked_count=0
  if [[ -f "$queue_file" ]]; then
    existing_checked=$(grep "^- \[x\]" "$queue_file" || true)
    if [[ -n "$existing_checked" ]]; then
      checked_count=$(echo "$existing_checked" | grep -c "." 2>/dev/null || echo 0)
    fi
  fi

  local low medium high total_count
  low=$(grep    "^low|"    "$data_file" | sort -t'|' -k2 -n || true)
  medium=$(grep "^medium|" "$data_file" | sort -t'|' -k2 -n || true)
  high=$(grep   "^high|"   "$data_file" | sort -t'|' -k2 -n || true)
  total_count=$(grep -c "." "$data_file" 2>/dev/null || echo 0)

  {
    echo "# Migration Queue"
    echo "<!-- Auto-generated by collect-init-overview.sh. Check off files as they are completed. -->"
    echo "<!-- Sorted: low risk first → high risk last. Easy wins come first. -->"
    echo "<!-- To migrate the next file, pick the first unchecked entry in Low Risk. -->"
    echo ""
    emit_tier "$low"    "Low Risk (< 100 lines, < 5 tests)" "$existing_checked"
    emit_tier "$medium" "Medium Risk (100–300 lines or 5–15 tests)" "$existing_checked"
    emit_tier "$high"   "High Risk (> 300 lines or > 15 tests)" "$existing_checked"
  } > "$queue_file"

  local rel_queue
  rel_queue=$(to_rel_path "$queue_file")
  echo ""
  if [[ $checked_count -gt 0 ]]; then
    echo "→ Queue updated: $rel_queue  ($total_count files, $checked_count already completed preserved)"
  else
    echo "→ Queue written: $rel_queue  ($total_count files total)"
  fi
}

# Preview mode: versions + status counts (no file list)
preview_mode() {
  echo "## Migration Init Preview"
  echo ""
  collect_versions
  echo ""
  count_test_statuses
}

# Main
main() {
  if [[ "$MODE" == "preview" ]]; then
    preview_mode
  else
    green "Collecting migration overview..."
    echo ""
    collect_versions
    echo ""
    count_test_statuses
    echo ""
    find_helpers
    echo ""
    collect_pipeline_facts
    echo ""
    find_risk_ordered_files
  fi
}

main
