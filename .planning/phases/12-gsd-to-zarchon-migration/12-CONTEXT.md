# Phase 12: GSD to Zarchon Migration - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Convert existing GSD projects to zarchon projects, preserving all work product (.planning/, ROADMAP.md, PLAN.md, SUMMARY.md, CONTEXT.md, config.json) while migrating to native Archon workflow execution.

</domain>

<decisions>
## Implementation Decisions

### Migration Scope
- **D-01:** Preserve `.planning/` artifacts exactly as-is — ROADMAP.md, PLANs, SUMMARYs, CONTEXT.md, config.json remain untouched
- **D-02:** GSD skills (`~/.claude/skills/`) are deprecated, not migrated — replaced by native Archon workflows
- **D-03:** Rename workflow prefixes: `gsd-*` → `zsd-*` (e.g., `zsd-plan`, `zsd-execute`, `zsd-discuss`)

### Tool Structure
- **D-04:** Use native Archon CLI (`archon workflow run zsd-*`) — no wrapper scripts
- **D-05:** Embrace Archon's background execution + dashboard for dual-terminal model (user-facing planning + headless implementation)

### Project Detection
- **D-06:** Detect GSD projects (`.planning/` without `.archon/`) and prompt for migration
- **D-07:** Migration markers: `.archon/` directory exists AND `config.json` has `"zarchon_version": "1.0"` field — both required

### Backward Compatibility
- **D-08:** Clean break — migrated projects are zarchon-only, no dual-mode support
- **D-09:** Migration is additive only — scaffold `.archon/workflows/` + add version to config.json, never modify/delete existing `.planning/` artifacts

### Claude's Discretion
- Specific workflow YAML structure (already drafted in `.archon/workflows/`)
- Config schema extension details beyond the version field
- Migration prompt UX (exact wording, CLI vs interactive)
- Error handling when migration markers are inconsistent

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing Archon Workflows (to rename gsd → zsd)
- `.archon/workflows/gsd-plan.yaml` — planning workflow (patterns → draft → check → revise → commit)
- `.archon/workflows/gsd-execute.yaml` — execution workflow (setup → implement loop → report)
- `.archon/workflows/gsd-discuss.yaml` — discussion workflow (load → adapt loop → decisions)
- `.archon/workflows/gsd-verify.yaml` — verification workflow
- `.archon/workflows/gsd-research.yaml` — research workflow
- `.archon/workflows/gsd-autonomous.yaml` — autonomous execution

### Project Config
- `.planning/config.json` — current config structure, needs `zarchon_version` field added

### Project Principles
- `.planning/PROJECT.md` — "Autonomous by default", "Config over hardcode"

### Archon Documentation
- https://github.com/coleam00/Archon — native CLI, background execution, worktrees, dashboard

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `.archon/workflows/*.yaml`: 18 workflow files already exist, need gsd→zsd rename
- `.planning/config.json`: existing config schema, extend with version field
- `~/dev/.meta/bin/ai-delegate`: multi-model routing system (Phases 02, 03, 11)

### Established Patterns
- YAML workflow structure with nodes, depends_on, model selection
- Phase artifacts in `.planning/phases/{NN}-{slug}/` directories
- Config-driven behavior via `.planning/config.json`

### Integration Points
- Archon CLI invocation: `archon workflow run {workflow} {args}`
- Background execution: `--background` flag or dashboard
- Git worktrees for parallel execution isolation

</code_context>

<specifics>
## Specific Ideas

- Work product preservation is the #1 priority — never lose ROADMAP.md, PLANs, SUMMARYs
- Dual-terminal model: user-facing Claude Code for planning, Archon background for headless implementation
- Migration should be a one-time operation, not an ongoing compatibility layer
- The `zsd-*` prefix makes the break from GSD explicit and avoids confusion

</specifics>

<deferred>
## Deferred Ideas

- **Archon dashboard customization** — configuring the web UI for zarchon-specific views (future milestone)
- **Multi-project orchestration** — running zarchon across multiple repos simultaneously (Phase 999.1 Parallel Session Orchestration)
- **Archon native process audit** — evaluating which Archon built-ins to adopt vs. keep custom (Phase 999.2)

</deferred>

---

*Phase: 12-gsd-to-zarchon-migration*
*Context gathered: 2026-04-18*
