# Phase 06: Phase Conventions - Research

**Researched:** 2026-04-18
**Domain:** Config-driven phase routing / workflow conventions
**Confidence:** HIGH

## Summary

This phase makes cleanup (999.x) and backlog (9999.x) phase number conventions config-driven instead of hardcoded in workflows. The config already exists in `.planning/config.json` with the `phase_conventions` section; the work is about making workflows consume it.

**Current state:** Workflows reference `999` as a magic number inline (e.g., `grep -v "999"` in review-pr skill). The config.json section is defined but unused.

**Primary recommendation:** Create a shared config reader (Node.js or bash function) that all workflows can source. Update workflows that reference phase numbers to read from config. Document the phase lifecycle semantics (completion, promotion).

## Workflow Inventory

### Workflows That Reference Phase Numbers or Routing

| Workflow | Location | Phase Reference | Type |
|----------|----------|-----------------|------|
| `review-pr` skill | `~/.claude/skills/review-pr/SKILL.md:196` | `grep -v "999"` — hardcoded | Filter |
| `gsd-code-review.yaml` | `.archon/workflows/gsd-code-review.yaml` | Routes to decimal phases | Implicit |
| `gsd-cleanup.yaml` | `.archon/workflows/gsd-cleanup.yaml` | Archives non-current phases | Implicit |
| `gsd-new-milestone.yaml` | `.archon/workflows/gsd-new-milestone.yaml:257` | "phase numbering and conventions" | Docs |
| `M001-ROADMAP.md` | `.planning/M001-ROADMAP.md:99` | "Non-blockers...999.x cleanup phase" | Policy |

**Analysis:** Only the `review-pr` skill has an explicit hardcoded phase number filter (`grep -v "999"`). Other workflows reference phases implicitly through directory patterns.

### Workflows With No Phase Routing Logic

| Workflow | Role |
|----------|------|
| `gsd-execute.yaml` | Executes tasks in a given phase (receives phase number) |
| `gsd-verify.yaml` | Verifies a phase (receives phase number) |
| `gsd-plan.yaml` | Plans a phase (receives phase number) |
| `gsd-discuss.yaml` | Discusses a phase (receives phase number) |
| `gsd-research.yaml` | Researches a phase (receives phase number) |
| `gsd-autonomous.yaml` | Chains plan+execute+verify (receives phase number) |
| `gsd-status.yaml` | Displays status (reads all phases) |
| `gsd-queue.yaml` | Queues milestones (no phase filtering) |
| `gsd-validate-phase.yaml` | Validates test coverage (receives phase number) |
| `gsd-audit-milestone.yaml` | Audits milestone (reads all phases) |
| `gsd-complete-milestone.yaml` | Archives milestone (reads all phases) |
| `gsd-extract-learnings.yaml` | Extracts lessons (receives phase number) |

**Key insight:** Most workflows receive a phase number as an argument and don't need to filter or route. The phase conventions primarily matter for:
1. **Routing decisions** (where to file non-blocking issues)
2. **Phase listing/filtering** (showing sequential phases vs. backlog)
3. **Phase creation** (naming new cleanup/backlog phases)

## Config Access Patterns

### Current Config Structure [VERIFIED: direct file read]

```json
{
  "phase_conventions": {
    "cleanup_series": 999,
    "backlog_series": 9999,
    "decimal_suffix_start": 1
  }
}
```

### How Workflows Currently Read Config

**No standard pattern exists.** [VERIFIED: grep shows no config.json access in workflows]

Workflows use:
- Inline bash (`$ARGUMENTS`, `$ARTIFACTS_DIR`)
- Direct file reads (`cat .planning/MILESTONE.md`)
- Pattern matching (`ls -d .planning/phases/${ARGUMENTS}-*/`)

### Recommended Config Access Pattern

**Option A: Node.js helper** (recommended if node is available)

```bash
# Usage in workflow bash nodes
CLEANUP_SERIES=$(node -pe "require('./.planning/config.json').phase_conventions.cleanup_series")
BACKLOG_SERIES=$(node -pe "require('./.planning/config.json').phase_conventions.backlog_series")
```

**Pros:** Node is available (v24.6.0 confirmed). Simple one-liner. No external deps.
**Cons:** Requires Node, slightly verbose for multiple reads.

**Option B: Centralized bash helper script**

Create `.archon/lib/config.sh`:
```bash
#!/bin/bash
# Load phase conventions from config
CONFIG_FILE="${PROJECT_ROOT:-.}/.planning/config.json"

get_config() {
  node -pe "require('$CONFIG_FILE').$1"
}

CLEANUP_SERIES=$(get_config 'phase_conventions.cleanup_series')
BACKLOG_SERIES=$(get_config 'phase_conventions.backlog_series')
DECIMAL_START=$(get_config 'phase_conventions.decimal_suffix_start')
```

**Pros:** Single source of truth. Easy to extend. Can add validation.
**Cons:** Requires sourcing in each workflow that needs it.

**Option C: Environment variable convention**

Set in project root or shell profile:
```bash
export GSD_CLEANUP_SERIES=999
export GSD_BACKLOG_SERIES=9999
```

**Cons:** Duplicates config, can drift. Not recommended.

**Recommendation:** Option A for immediate use in individual workflows, Option B as the eventual pattern when more config values need reading.

## Phase Lifecycle Semantics

### Sequential Phases (01-99)

| State | Meaning | Transition |
|-------|---------|------------|
| Directory created | Phase scoped, not started | `gsd-discuss` → decisions locked |
| PLAN.md exists | Ready for execution | `gsd-execute` → progress tracking |
| VERIFICATION.md exists | Executed, verified | Phase complete |

### Decimal Phases (XX.1, XX.2, ...)

| State | Purpose | Creation Trigger |
|-------|---------|------------------|
| XX.1 | First remediation for phase XX | PR review finds blocking issues |
| XX.2 | Second remediation | Previous decimal phase didn't fully fix |

**Completion:** Decimal phase completes when VERIFICATION.md shows PASS. Does not auto-increment; next decimal is only created when needed.

### Cleanup Phase (999.x) [ASSUMED]

| State | Purpose | Completion |
|-------|---------|------------|
| 999.1 | First cleanup backlog item | When all issues addressed |
| 999.2 | Second cleanup backlog | When all issues addressed |

**Semantics:**
- `999.1` → `999.2`: Auto-increment when `999.1` completes
- These are persistent backlog lanes, not one-shot phases
- Items added here from: non-blocking PR review findings, deferred cleanup from main phases

**Creation:**
- On-demand when an issue is routed to cleanup
- Directory structure: `.planning/phases/999.1-cleanup/`, `.planning/phases/999.2-cleanup/`

### Backlog Phase (9999.x) [ASSUMED]

| State | Purpose | Completion |
|-------|---------|------------|
| 9999.1 | Parking lot item 1 | When promoted to sequential phase |
| 9999.x | Parking lot item N | When promoted or discarded |

**Semantics:**
- Items here are ideas, not active work
- **Promotion:** User decides to work on it → moves to sequential phase
- **Completion:** Does NOT auto-increment to 9999.2; item is either promoted or archived

**Key difference:** 999.x items are "do this eventually"; 9999.x items are "maybe never, but don't forget".

## Directory Structure Recommendations

### Current Structure [VERIFIED: ls output]

```
.planning/
├── phases/
│   ├── 01-model-registry/
│   └── 04-zai-ollama-integration/
└── milestones/
    └── M001-phases/
        └── ...
```

### Recommended Cleanup/Backlog Structure

**Option A: Flat under phases/**
```
.planning/phases/
├── 01-model-registry/
├── 999.1-cleanup-first/
├── 999.2-cleanup-second/
├── 9999.1-backlog-idea-a/
└── 9999.2-backlog-idea-b/
```

**Option B: Nested by series**
```
.planning/phases/
├── sequential/
│   ├── 01-model-registry/
├── cleanup/
│   ├── 999.1-first/
│   └── 999.2-second/
└── backlog/
    ├── 9999.1-idea-a/
```

**Recommendation:** Option A (flat) for simplicity. The numeric prefix provides natural sorting (999 > 99, 9999 > 999), and existing workflow patterns (`ls -d .planning/phases/[0-9]*/`) continue to work with minor adjustment.

### Directory Creation Policy

**On-demand, not pre-created.** When an issue is routed to 999.x or 9999.x:
1. Check if `999.${N}-*` exists for any N
2. Find highest N, use N+1 (or 1 if none)
3. Create directory with descriptive slug: `999.1-pr-42-cleanup/`

## Code Examples

### Reading Phase Conventions [VERIFIED: node syntax]

```bash
# In workflow bash node
CLEANUP_SERIES=$(node -pe "require('./.planning/config.json').phase_conventions?.cleanup_series || 999")
BACKLOG_SERIES=$(node -pe "require('./.planning/config.json').phase_conventions?.backlog_series || 9999")
```

### Filtering Sequential Phases

**Before (hardcoded):**
```bash
ls -d .planning/phases/[0-9]*/ | grep -v "999"
```

**After (config-driven):**
```bash
CLEANUP_SERIES=$(node -pe "require('./.planning/config.json').phase_conventions.cleanup_series")
ls -d .planning/phases/[0-9]*/ | grep -v "^\..*/${CLEANUP_SERIES}"
```

### Finding Next Cleanup Phase Number

```bash
CLEANUP_SERIES=$(node -pe "require('./.planning/config.json').phase_conventions.cleanup_series")
DECIMAL_START=$(node -pe "require('./.planning/config.json').phase_conventions.decimal_suffix_start")

# Find existing cleanup phases
LAST_CLEANUP=$(ls -d .planning/phases/${CLEANUP_SERIES}.*-*/ 2>/dev/null | sort -V | tail -1)

if [ -z "$LAST_CLEANUP" ]; then
  NEXT_NUM="${CLEANUP_SERIES}.${DECIMAL_START}"
else
  LAST_NUM=$(basename "$LAST_CLEANUP" | grep -oE "^${CLEANUP_SERIES}\.[0-9]+" | cut -d. -f2)
  NEXT_NUM="${CLEANUP_SERIES}.$((LAST_NUM + 1))"
fi

echo "Next cleanup phase: $NEXT_NUM"
```

### Creating a Phase Directory

```bash
create_phase_dir() {
  local PHASE_NUM="$1"
  local SLUG="$2"
  local DIR=".planning/phases/${PHASE_NUM}-${SLUG}"

  mkdir -p "$DIR"
  echo "$DIR"
}

# Usage
NEW_DIR=$(create_phase_dir "999.1" "pr-42-cleanup")
```

## Implementation Approach

### Files to Create

| File | Purpose | Effort |
|------|---------|--------|
| `.archon/lib/config.sh` | Shared config reader | Small |
| (none) | Config already exists | — |

### Files to Update

| File | Change | Effort |
|------|--------|--------|
| `~/.claude/skills/review-pr/SKILL.md` | Replace `grep -v "999"` with config read | Small |
| `gsd-code-review.yaml` | (review routing logic - if any) | Audit needed |
| Documentation | Phase lifecycle semantics | Small |

### No Changes Needed

| File | Reason |
|------|--------|
| `gsd-execute.yaml` | Receives phase as arg, no filtering |
| `gsd-verify.yaml` | Receives phase as arg, no filtering |
| `gsd-plan.yaml` | Receives phase as arg, no filtering |
| `gsd-discuss.yaml` | Receives phase as arg, no filtering |
| Most other workflows | Don't filter by phase series |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing in bash | Custom awk/sed | `node -pe` | Reliable, handles edge cases |
| Phase number sorting | String sort | `sort -V` | Version sort handles X.Y correctly |
| Config schema validation | Nothing | JSON Schema (later) | Not needed for MVP |

## Common Pitfalls

### Pitfall 1: String vs Numeric Comparison

**What goes wrong:** `999 > 99` fails in string comparison.
**Why it happens:** Bash string sort puts "99" after "999" alphabetically.
**How to avoid:** Use `sort -V` (version sort) or numeric comparison.
**Warning signs:** Cleanup phases appearing before phase 99.

### Pitfall 2: Config File Not Found

**What goes wrong:** Node.js `require()` throws if file missing.
**Why it happens:** Running from wrong directory, config not committed.
**How to avoid:** Use optional chaining with fallback: `?.cleanup_series || 999`
**Warning signs:** Workflow fails with "Cannot find module".

### Pitfall 3: Decimal Phase Collision

**What goes wrong:** Creating 999.1 when it already exists.
**Why it happens:** Not checking for existing directories.
**How to avoid:** Always find max existing, then increment.
**Warning signs:** Overwritten phase directories.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | 999.x auto-increments on completion | Phase Lifecycle Semantics | Confusing UX if phases pile up |
| A2 | 9999.x completes by promotion only | Phase Lifecycle Semantics | Lost backlog items |
| A3 | Flat directory structure preferred | Directory Structure | Harder navigation if many phases |

## Open Questions

1. **Should cleanup phases auto-increment?**
   - What we know: 999.1 → 999.2 is documented intention
   - What's unclear: What triggers the transition? Completion of all issues? Manual?
   - Recommendation: Treat completion of 999.1 as creating 999.2 only when a new cleanup item arrives, not automatically.

2. **Phase directory under phases/ or milestones/**
   - What we know: Both exist (phases/ and milestones/M001-phases/)
   - What's unclear: Which is canonical for cleanup/backlog?
   - Recommendation: Use `.planning/phases/` for milestone-independent backlog; `.planning/milestones/M001-phases/` for sequential phases that belong to a specific milestone.

3. **What happens to 999.x across milestones?**
   - What we know: 999.x is "non-blocking cleanup"
   - What's unclear: Does cleanup persist across milestone boundaries?
   - Recommendation: Ask user during discuss phase. Options: (a) cleanup is milestone-scoped, (b) cleanup is project-wide.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | Config reading | Yes | v24.6.0 | Python/bash (awkward) |
| jq | JSON parsing | No | — | node -pe (preferred) |
| sort -V | Version sorting | Yes | GNU coreutils | — |

**Missing dependencies with no fallback:** None

**Missing dependencies with fallback:** jq (use node -pe instead)

## Sources

### Primary (HIGH confidence)
- `/home/zzs/dev/zarchon/.planning/config.json` — verified phase_conventions exists
- `/home/zzs/dev/zarchon/.archon/workflows/*.yaml` — all 17 workflows reviewed
- `/home/zzs/.claude/skills/review-pr/SKILL.md` — reviewed for 999.x logic

### Secondary (MEDIUM confidence)
- `/home/zzs/dev/zarchon/.planning/M001-ROADMAP.md` — phase 06 requirements
- `/home/zzs/dev/zarchon/.planning/PROJECT.md` — phase conventions documented

### Tertiary (LOW confidence)
- Phase lifecycle semantics — inferred from docs, needs user confirmation

## Metadata

**Confidence breakdown:**
- Workflow inventory: HIGH — all files read and analyzed
- Config access patterns: HIGH — verified node availability and syntax
- Phase lifecycle semantics: MEDIUM — documented but completion semantics assumed
- Directory structure: MEDIUM — current structure verified, recommendations assumed

**Research date:** 2026-04-18
**Valid until:** Indefinitely (internal project conventions, not external deps)
