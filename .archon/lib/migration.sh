#!/usr/bin/env bash
# migration.sh — Migration detection utilities for GSD-to-zarchon migration
#
# Usage: source this file in workflows that need to detect project state
#   source .archon/lib/migration.sh
#   if is_gsd_project; then
#     echo "This is a legacy GSD project. Run migration."
#   fi
#
# Detection logic per D-07:
# - Zarchon project: .archon/ directory exists AND config.json has zarchon_version field
# - GSD project: .planning/ exists but NOT a zarchon project
# - Neither: fresh project (no .planning/)

set -euo pipefail

# _has_json_field — Internal helper to check if JSON file has a field
# Falls back to node if jq is not available
_has_json_field() {
  local file="$1"
  local field="$2"

  # Try jq first (most common tool)
  if command -v jq >/dev/null 2>&1; then
    jq -e ".${field}" "$file" >/dev/null 2>&1
    return $?
  fi

  # Fallback to node (available in most dev environments)
  if command -v node >/dev/null 2>&1; then
    node -e "const fs=require('fs');const obj=JSON.parse(fs.readFileSync('$file','utf8'));process.exit(obj.$field !== undefined ? 0 : 1);" 2>/dev/null
    return $?
  fi

  # No JSON parser available - fail gracefully
  return 1
}

# is_zarchon_migrated — Returns 0 (true) if project is fully migrated to zarchon
# Requires BOTH markers per D-07:
#   1. .archon/ directory exists
#   2. .planning/config.json has "zarchon_version" field
is_zarchon_migrated() {
  local project_root="${1:-.}"

  # Check for .archon directory
  if [ ! -d "${project_root}/.archon" ]; then
    return 1
  fi

  # Check for zarchon_version field in config.json
  if [ ! -f "${project_root}/.planning/config.json" ]; then
    return 1
  fi

  # Check for the version field using available JSON parser
  if ! _has_json_field "${project_root}/.planning/config.json" "zarchon_version"; then
    return 1
  fi

  return 0
}

# is_gsd_project — Returns 0 (true) if project is a legacy GSD project needing migration
# Criteria: has .planning/ but is NOT a zarchon project
is_gsd_project() {
  local project_root="${1:-.}"

  # Must have .planning/ directory (it's a GSD project of some kind)
  if [ ! -d "${project_root}/.planning" ]; then
    return 1
  fi

  # Must NOT be already migrated to zarchon
  if is_zarchon_migrated "${project_root}"; then
    return 1
  fi

  return 0
}

# is_partial_migration — Returns 0 (true) if migration is in an inconsistent state
# This is an error condition: one marker exists without the other
is_partial_migration() {
  local project_root="${1:-.}"
  local has_archon_dir=false
  local has_version_field=false

  [ -d "${project_root}/.archon" ] && has_archon_dir=true

  if [ -f "${project_root}/.planning/config.json" ]; then
    _has_json_field "${project_root}/.planning/config.json" "zarchon_version" && has_version_field=true
  fi

  # Partial = exactly one marker, not both, not neither
  if $has_archon_dir && ! $has_version_field; then
    return 0  # Has .archon/ but no version field
  fi

  if ! $has_archon_dir && $has_version_field; then
    return 0  # Has version field but no .archon/
  fi

  return 1  # Either both or neither — not partial
}

# migration_status — Print human-readable migration status
migration_status() {
  local project_root="${1:-.}"

  if is_zarchon_migrated "${project_root}"; then
    echo "zarchon"
  elif is_gsd_project "${project_root}"; then
    echo "gsd"
  elif is_partial_migration "${project_root}"; then
    echo "partial"
  elif [ -d "${project_root}/.planning" ]; then
    echo "unknown"
  else
    echo "fresh"
  fi
}
