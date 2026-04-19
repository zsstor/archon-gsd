# Phase 12: GSD to Zarchon Migration - Research

**Researched:** 2026-04-18
**Domain:** Workflow migration, file renaming, config schema extension
**Confidence:** HIGH

## Summary

This phase migrates existing GSD-based projects to zarchon, which is a faithful GSD-2 replication built on the Archon YAML workflow engine. The migration is **additive only** — it scaffolds `.archon/workflows/` with renamed workflows (`gsd-*` to `zsd-*`) and adds a `zarchon_version` field to `.planning/config.json`, while preserving all existing work product in `.planning/`.

The migration is straightforward: 18 existing YAML workflow files need filename and internal reference renames. The config.json schema extension is minimal — a single version field. Detection is based on dual markers (`.archon/` directory + version field). GSD skills in `~/.claude/skills/gsd-*` are deprecated (not migrated) since Archon workflows are full reimplementations.

**Primary recommendation:** Execute a mechanical rename of all workflow files and their internal `gsd-*` references to `zsd-*`, add the `zarchon_version` field to config.json, and document the migration markers for future project detection.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Preserve `.planning/` artifacts exactly as-is — ROADMAP.md, PLANs, SUMMARYs, CONTEXT.md, config.json remain untouched
- **D-02:** GSD skills (`~/.claude/skills/`) are deprecated, not migrated — replaced by native Archon workflows
- **D-03:** Rename workflow prefixes: `gsd-*` to `zsd-*` (e.g., `zsd-plan`, `zsd-execute`, `zsd-discuss`)
- **D-04:** Use native Archon CLI (`archon workflow run zsd-*`) — no wrapper scripts
- **D-05:** Embrace Archon's background execution + dashboard for dual-terminal model (user-facing planning + headless implementation)
- **D-06:** Detect GSD projects (`.planning/` without `.archon/`) and prompt for migration
- **D-07:** Migration markers: `.archon/` directory exists AND `config.json` has `"zarchon_version": "1.0"` field — both required
- **D-08:** Clean break — migrated projects are zarchon-only, no dual-mode support
- **D-09:** Migration is additive only — scaffold `.archon/workflows/` + add version to config.json, never modify/delete existing `.planning/` artifacts

### Claude's Discretion
- Specific workflow YAML structure (already drafted in `.archon/workflows/`)
- Config schema extension details beyond the version field
- Migration prompt UX (exact wording, CLI vs interactive)
- Error handling when migration markers are inconsistent

### Deferred Ideas (OUT OF SCOPE)
- Archon dashboard customization — configuring the web UI for zarchon-specific views (future milestone)
- Multi-project orchestration — running zarchon across multiple repos simultaneously (Phase 999.1 Parallel Session Orchestration)
- Archon native process audit — evaluating which Archon built-ins to adopt vs. keep custom (Phase 999.2)
</user_constraints>

## Standard Stack

### Core
| Library/Tool | Version | Purpose | Why Standard |
|--------------|---------|---------|--------------|
| Archon CLI | v0.3.6+ | YAML workflow engine | Native CLI for workflow execution [VERIFIED: archon.diy install endpoint] |
| Bash/Shell | system | File operations, git | Universal, no dependencies |
| jq | system | JSON manipulation | Standard for config.json edits [ASSUMED] |
| sed/awk | system | Text replacement in YAML | Standard Unix tools for bulk rename |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| git | system | Commit migration changes | All file operations should be atomic commits |
| yq | 4.x | YAML manipulation | Alternative to sed for structured YAML edits [ASSUMED] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| sed for YAML | yq (YAML parser) | yq is safer but requires installation; sed is already available |
| Manual rename | Script automation | Automation is mandatory for 18 files + cross-references |

**Installation:**
```bash
# Archon CLI (already installed per SETUP.md)
curl -fsSL https://archon.diy/install | INSTALL_DIR=~/.local/bin bash
```

**Version verification:** Archon CLI is distributed as a binary via archon.diy/install. The install endpoint is active (HTTP 200 verified via curl). [VERIFIED: archon.diy/install endpoint]

## Architecture Patterns

### Migration Directory Structure
```
<project>/
├── .archon/
│   └── workflows/           # 18 renamed zsd-*.yaml files
│       ├── zsd-plan.yaml
│       ├── zsd-execute.yaml
│       ├── zsd-discuss.yaml
│       ├── zsd-verify.yaml
│       ├── zsd-research.yaml
│       ├── zsd-autonomous.yaml
│       └── ... (12 more)
├── .planning/               # UNCHANGED — preserved exactly
│   ├── config.json          # ADD: "zarchon_version": "1.0"
│   ├── ROADMAP.md
│   ├── MILESTONE.md
│   └── milestones/          # All phase artifacts unchanged
└── ...
```

### Pattern 1: Additive-Only Migration
**What:** The migration adds new files/fields without modifying or deleting existing artifacts.
**When to use:** When work product preservation is paramount.
**Example:**
```bash
# CORRECT: Add version field to config.json
jq '. + {"zarchon_version": "1.0"}' .planning/config.json > tmp && mv tmp .planning/config.json

# WRONG: Would overwrite existing content
# echo '{"zarchon_version": "1.0"}' > .planning/config.json
```

### Pattern 2: Mechanical Bulk Rename
**What:** All 18 workflow files are renamed using a consistent pattern.
**When to use:** When prefix changes apply uniformly across all files.
**Example:**
```bash
# Filename rename
for f in .archon/workflows/gsd-*.yaml; do
  newname=$(echo "$f" | sed 's/gsd-/zsd-/')
  mv "$f" "$newname"
done

# Internal reference update (inside YAML files)
for f in .archon/workflows/zsd-*.yaml; do
  sed -i 's/gsd-/zsd-/g' "$f"
done
```

### Pattern 3: Dual-Marker Detection
**What:** Migration status requires BOTH `.archon/` existence AND `zarchon_version` field in config.json.
**When to use:** Belt-and-suspenders detection to avoid partial migration states.
**Example:**
```bash
is_migrated() {
  [ -d ".archon" ] && jq -e '.zarchon_version' .planning/config.json >/dev/null 2>&1
}

if ! is_migrated; then
  echo "GSD project detected. Run migration?"
fi
```

### Anti-Patterns to Avoid
- **Modifying .planning/ artifacts:** Never edit ROADMAP.md, PLANs, SUMMARYs, or CONTEXT.md during migration.
- **Partial rename:** All 18 files must be renamed atomically; partial state causes Archon to fail workflow discovery.
- **Wrapper scripts:** D-04 mandates native Archon CLI; don't create `zsd-plan` shell scripts.
- **Dual-mode support:** D-08 specifies clean break; don't maintain compatibility with GSD tools post-migration.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON config editing | Manual JSON string manipulation | `jq` command-line tool | jq handles edge cases (escaping, formatting, nested objects) |
| YAML parsing | Regex-based parsing | sed for simple substitution or yq for structured | YAML is context-sensitive; simple prefix replace with sed is sufficient for this use case |
| Directory scaffolding | Manual mkdir chains | Standard shell patterns | No framework needed |
| Migration detection | Custom marker file | Existing config.json field | Reuse existing config infrastructure per D-07 |

**Key insight:** This migration is mechanical file operations, not complex logic. Standard Unix tools (sed, jq, mv, cp) are the right level of abstraction.

## Common Pitfalls

### Pitfall 1: Incomplete Internal Reference Update
**What goes wrong:** Workflow files reference each other by name (e.g., `archon workflow run gsd-execute`). Missing internal references causes runtime errors.
**Why it happens:** Renaming filenames without updating content.
**How to avoid:** After filename rename, run `grep -r "gsd-" .archon/workflows/` to find remaining references.
**Warning signs:** `archon workflow run zsd-autonomous` fails with "workflow not found" errors.

### Pitfall 2: Partial Migration State
**What goes wrong:** `.archon/` directory exists but version field missing (or vice versa).
**Why it happens:** Interrupted migration or manual partial fix.
**How to avoid:** Migration script must be atomic — all changes or rollback.
**Warning signs:** Detection logic returns inconsistent results.

### Pitfall 3: Config.json Schema Breakage
**What goes wrong:** Existing config.json has complex structure; naive JSON manipulation corrupts it.
**Why it happens:** Using echo/printf instead of jq for JSON editing.
**How to avoid:** Always use `jq` for JSON manipulation; test round-trip before committing.
**Warning signs:** JSON parse errors on subsequent workflow runs.

### Pitfall 4: Archon Nesting Deadlock
**What goes wrong:** Running `archon workflow run` from inside a Claude Code session causes silent hang.
**Why it happens:** Archon spawns a nested `claude` subprocess that deadlocks on the parent session's IPC.
**How to avoid:** Always run Archon from a plain terminal, not from within Claude Code.
**Warning signs:** `archon workflow run` hangs indefinitely without output.

### Pitfall 5: Missing Workflow Cross-References in README/SETUP
**What goes wrong:** Documentation still references `gsd-*` commands after rename.
**Why it happens:** Forgetting to update README.md, SETUP.md, and PROJECT.md.
**How to avoid:** Include documentation files in the rename scope.
**Warning signs:** User confusion; outdated examples in docs.

## Code Examples

Verified patterns from existing codebase:

### Workflow File Rename
```bash
# Source: Derived from .archon/workflows/ structure
cd /home/zzs/dev/zarchon/.archon/workflows/

# List all files to rename
ls gsd-*.yaml
# gsd-audit-milestone.yaml  gsd-cleanup.yaml  gsd-code-review.yaml
# gsd-complete-milestone.yaml  gsd-discuss.yaml  gsd-eval-review.yaml
# gsd-execute.yaml  gsd-extract-learnings.yaml  gsd-new-milestone.yaml
# gsd-plan.yaml  gsd-queue.yaml  gsd-research.yaml  gsd-secure-phase.yaml
# gsd-status.yaml  gsd-ui-review.yaml  gsd-validate-phase.yaml
# gsd-verify.yaml  gsd-autonomous.yaml

# Rename all 18 files
for f in gsd-*.yaml; do
  mv "$f" "${f/gsd-/zsd-}"
done
```

### Internal Reference Update
```bash
# Source: Grep of existing cross-references
# These patterns appear in workflow files:
#   archon workflow run gsd-*
#   name: gsd-*
#   gsd-plan.yaml, gsd-execute.yaml, etc.

for f in zsd-*.yaml; do
  sed -i 's/gsd-/zsd-/g' "$f"
done
```

### Config Version Field Addition
```bash
# Source: .planning/config.json structure
# Add zarchon_version field to existing config

jq '. + {"zarchon_version": "1.0"}' .planning/config.json > /tmp/config.tmp \
  && mv /tmp/config.tmp .planning/config.json
```

### Migration Detection Function
```bash
# Source: D-06 and D-07 from CONTEXT.md

is_zarchon_migrated() {
  local has_archon_dir=false
  local has_version_field=false

  [ -d ".archon" ] && has_archon_dir=true
  jq -e '.zarchon_version' .planning/config.json >/dev/null 2>&1 && has_version_field=true

  $has_archon_dir && $has_version_field
}

is_gsd_project() {
  [ -d ".planning" ] && ! is_zarchon_migrated
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| GSD skills (`~/.claude/skills/gsd-*`) | Archon workflows (`.archon/workflows/`) | This phase | Skills deprecated, workflows are full reimplementations |
| GSD-CC commands (`/gsd-*`) | Archon CLI (`archon workflow run zsd-*`) | This phase | Clean break; no dual-mode |
| Implicit project detection | Dual-marker detection | This phase | Explicit migration status |

**Deprecated/outdated:**
- GSD skills in `~/.claude/skills/gsd-*`: 29+ skills found, all deprecated — replaced by Archon workflows
- GSD-CC invocation style (`/gsd-plan-phase`): Replaced by `archon workflow run zsd-plan`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `jq` is available on target systems | Standard Stack | Migration script would need fallback; low risk on Linux/WSL |
| A2 | `yq` 4.x is an alternative to sed for YAML | Standard Stack | Only affects alternative path; primary path uses sed |
| A3 | sed -i works consistently across Linux/macOS | Code Examples | macOS requires different sed syntax; plan should verify |

## Open Questions

1. **macOS sed compatibility**
   - What we know: macOS sed requires `sed -i ''` instead of `sed -i`
   - What's unclear: Whether this migration will run on macOS or only Linux/WSL
   - Recommendation: Use `sed -i.bak` and delete backup, or detect OS and branch

2. **Documentation update scope**
   - What we know: README.md and SETUP.md reference `gsd-*` commands
   - What's unclear: Whether PROJECT.md and other files also need updates
   - Recommendation: Include all markdown files in grep scope for `gsd-` references

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Archon CLI | All workflow execution | To verify | v0.3.6+ expected | None — required |
| jq | Config.json editing | To verify | Any | Manual JSON editing (not recommended) |
| sed | YAML bulk rename | Yes | system | awk or yq |
| git | Atomic commits | Yes | system | None — required |
| bash | Migration script | Yes | system | None — required |

**Missing dependencies with no fallback:**
- Archon CLI must be installed per SETUP.md instructions

**Missing dependencies with fallback:**
- jq: Can use Python or manual editing as fallback, but jq is strongly preferred

## Sources

### Primary (HIGH confidence)
- `.archon/workflows/*.yaml` — 18 workflow files examined for structure and cross-references [VERIFIED: file read]
- `.planning/config.json` — existing config schema structure [VERIFIED: file read]
- `.planning/phases/12-gsd-to-zarchon-migration/12-CONTEXT.md` — locked decisions D-01 through D-09 [VERIFIED: file read]
- `README.md` and `SETUP.md` — Archon CLI installation and usage [VERIFIED: file read]

### Secondary (MEDIUM confidence)
- https://github.com/coleam00/Archon — Archon project documentation [VERIFIED: WebFetch]
- archon.diy/install — install endpoint [VERIFIED: curl HEAD request]

### Tertiary (LOW confidence)
- None — all claims verified against codebase or official sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — tools are standard Unix utilities + installed Archon CLI
- Architecture: HIGH — pattern derived from existing workflow structure
- Pitfalls: HIGH — based on documented Archon constraints (SETUP.md) and mechanical analysis

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (30 days — stable domain, mechanical migration)
