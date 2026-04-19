---
phase: 06-phase-conventions
plan: 01
subsystem: workflow-config
tags: [config, phase-conventions, review-pr, skill-update]

dependency_graph:
  requires:
    - .planning/config.json (phase_conventions section)
  provides:
    - config-driven phase filtering in review-pr skill
  affects:
    - ~/.claude/skills/review-pr/SKILL.md

tech_stack:
  patterns:
    - node -pe for JSON config access (no jq dependency)
    - glob [0-9]*/ to naturally exclude alphabetic prefixes

key_files:
  modified:
    - ~/.claude/skills/review-pr/SKILL.md (config-driven filtering)
  verified:
    - .planning/config.json (DEBT/PARK/WANT prefixes present)
    - .planning/PROJECT.md (lifecycle documentation present)

decisions:
  - "Use glob pattern [0-9]*/ instead of grep -v filter - naturally excludes DEBT.x, PARK.x, WANT.x"
  - "Read config with node -pe since jq not installed"

metrics:
  duration: 83s
  completed: 2026-04-18T16:13:00Z
  tasks: 3/3
  files: 1 modified, 2 verified
---

# Phase 06 Plan 01: Phase Conventions Summary

Config-driven phase filtering in review-pr skill using node -pe to read DEBT/PARK/WANT prefixes from .planning/config.json.

## What Was Done

### Task 1: Verify config.json has phase conventions (Verification Only)

Confirmed `.planning/config.json` already contains complete `phase_conventions` section:
- `cleanup_prefix: "DEBT"`
- `backlog_prefix: "PARK"`
- `issues_prefix: "WANT"`
- `decimal_suffix_start: 1`
- `scope: "milestone"`

No changes required.

### Task 2: Update review-pr skill to read from config

Updated `~/.claude/skills/review-pr/SKILL.md` (lines 194-202):

**Before:**
```bash
# Find last numbered phase before backlog (999.x)
LAST_PHASE=$(ls -d .planning/phases/[0-9]*/ 2>/dev/null | grep -v "999" | sort -V | tail -1 | grep -oE '[0-9]+' | head -1)
```

**After:**
```bash
# Read phase prefixes from config (DEBT, PARK, WANT)
CLEANUP_PREFIX=$(node -pe "require('./.planning/config.json').phase_conventions?.cleanup_prefix || 'DEBT'")
BACKLOG_PREFIX=$(node -pe "require('./.planning/config.json').phase_conventions?.backlog_prefix || 'PARK'")

# Find last numbered phase before special phases (DEBT.x, PARK.x, WANT.x)
# Sequential phases are numeric only; [0-9]*/ naturally excludes alphabetic prefixes
LAST_PHASE=$(ls -d .planning/phases/[0-9]*/ 2>/dev/null | sort -V | tail -1 | grep -oE '^[0-9]+' | head -1)
```

**Key insight:** The glob `[0-9]*/` naturally excludes DEBT.x, PARK.x, WANT.x since they start with letters, not digits. No explicit filter needed.

**Note:** `~/.claude/skills/` is a user-level configuration directory, not version-controlled. The change is applied but not committed to git.

### Task 3: Verify PROJECT.md documents lifecycle (Verification Only)

Confirmed `.planning/PROJECT.md` contains complete lifecycle documentation:
- DEBT.x lifecycle (catch-all, manual increment when closed)
- PARK.x lifecycle (completes when promoted to sequential phase)
- WANT.x lifecycle (auto-created from GitHub issues, completes on promotion)

9 references to lifecycle concepts found. No changes required.

## Verification Results

```
Task 1: node -pe "...phase_conventions..." => DEBT,PARK,WANT [PASS]
Task 2: grep "node -pe.*phase_conventions" ~/.claude/skills/review-pr/SKILL.md [PASS]
Task 2: grep "999" ~/.claude/skills/review-pr/SKILL.md [PASS - not found]
Task 3: grep "DEBT.x|PARK.x|WANT.x" PROJECT.md => 9 matches [PASS]
```

## Deviations from Plan

None - plan executed exactly as written.

## Notes

The review-pr skill file (`~/.claude/skills/review-pr/SKILL.md`) is outside the project repository. It lives in the user's personal Claude configuration directory, which is intentionally not version-controlled. The modification was applied successfully but does not produce a git commit in the zarchon repo.

## Self-Check: PASSED

- [x] Config.json verified with correct values
- [x] review-pr skill updated with config-driven filtering
- [x] No hardcoded "999" remains
- [x] PROJECT.md verified with lifecycle documentation
- [x] All verification commands pass
