# Phase 12: GSD to Zarchon Migration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 12-gsd-to-zarchon-migration
**Areas discussed:** Migration Scope, Tool Structure, Project Detection, Backward Compat

---

## Migration Scope

### Artifacts Preservation

| Option | Description | Selected |
|--------|-------------|----------|
| Preserve all | Keep everything in .planning/ as-is — zarchon reads/writes same structure | ✓ |
| Migrate to new format | Transform existing artifacts to a new zarchon-specific format/location | |
| Hybrid approach | Keep structure, upgrade config schema, add migration metadata | |

**User's choice:** Preserve all
**Notes:** Work product is sacred — ROADMAP.md, PLANs, SUMMARYs must remain exactly as-is.

### Skills Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Keep GSD skills separate | Skills stay in ~/.claude/skills/, zarchon can call as fallback | |
| Migrate skills to zarchon | Copy/move skills to ~/.archon/skills/ | |
| Shared skill registry | Both tools read from same skill locations | |
| Deprecated (no migration) | Skills replaced by native .archon/workflows/ | ✓ |

**User's choice:** Deprecated — skills are replaced, not migrated
**Notes:** User asked to inspect .archon/workflows/ — confirmed they are full reimplementations (gsd-plan.yaml, gsd-execute.yaml, gsd-discuss.yaml). Not wrappers. Skills become legacy.

### Workflow Prefix

**User's choice:** Rename `gsd-*` → `zsd-*`
**Notes:** Makes the break explicit, avoids confusion between GSD and zarchon.

---

## Tool Structure

### Invocation Pattern

| Option | Description | Selected |
|--------|-------------|----------|
| archon workflow run zsd-X | Native Archon CLI, full access to features | ✓ |
| zsd-X (wrapper script) | Thin wrappers for familiar GSD-style invocation | |
| Both available | Native + wrappers for convenience | |

**User's choice:** Native Archon CLI
**Notes:** User asked about Archon tradeoffs. After explaining background execution, worktrees, and dashboard capabilities — decided to fully embrace Archon rather than wrapping it. Key insight: dual-terminal model (user-facing planning + headless implementation) maps directly to Archon's architecture.

---

## Project Detection

### Detection Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Detect + prompt migrate | If .planning/ exists but no .archon/, offer one-time migration | ✓ |
| Auto-migrate silently | Automatically create .archon/workflows/ on first run | |
| Explicit migrate command | Users run `archon migrate` manually | |

**User's choice:** Detect + prompt migrate

### Migration Markers

| Option | Description | Selected |
|--------|-------------|----------|
| .archon/ directory exists | Simple presence check | |
| config.json version field | Add `"zarchon_version": "1.0"` | |
| Both markers required | .archon/ AND version field | ✓ |

**User's choice:** Both markers required (belt + suspenders)

---

## Backward Compatibility

### GSD Compatibility

| Option | Description | Selected |
|--------|-------------|----------|
| Clean break | Migrated projects are zarchon-only | ✓ |
| Dual-mode support | Keep artifacts compatible for both tools | |
| Read-only GSD compat | GSD tools can read but not write | |

**User's choice:** Clean break

### Migration Operation

**User's choice:** Additive only — scaffold .archon/workflows/, add version to config.json, never modify/delete existing .planning/ artifacts
**Notes:** User emphasized "most important thing is to get all planning docs readable and preserve all roadmaps."

---

## Claude's Discretion

- Specific workflow YAML structure
- Config schema extension details beyond version field
- Migration prompt UX
- Error handling for inconsistent markers

## Deferred Ideas

- Archon dashboard customization
- Multi-project orchestration (Phase 999.1)
- Archon native process audit (Phase 999.2)
