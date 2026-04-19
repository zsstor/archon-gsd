# Phase 02: Task→Model Routing - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Given a task description, route it to the best available model based on complexity, task type, and history. The routing system learns from outcomes and auto-adjusts per task type.

</domain>

<decisions>
## Implementation Decisions

### Complexity Scoring
- **D-01:** Implement three scoring modes: `keyword`, `keyword+files`, `full` — all available, configurable per task type
- **D-02:** Each task type starts on `keyword` mode and auto-upgrades independently based on observed outcomes
- **D-03:** Dual-signal auto-upgrade trigger: failure rate threshold OR escalation count threshold (either can trigger upgrade)
- **D-04:** Score format is numeric 0-100 internally (thresholds configurable, easy to log and analyze)

### History Lookup
- **D-05:** Time-decayed weights per task type — recent failures weigh more than old ones
- **D-06:** All outcome fields feed into routing: success, escalation_count, tokens_used, duration_ms
- **D-07:** Each task type maintains its own history/decay curve independently

### Routing Architecture
- **D-08:** Single smart CLI — rewrite `ai-delegate` with intentional design (current version is organic MVP)
- **D-09:** Clean internal module separation: routing module, execution module, logging module
- **D-10:** Routing module owns: scoring, history lookup, model selection
- **D-11:** Execution module owns: backend dispatch, timeout handling, output capture
- **D-12:** Logging module owns: outcome recording, introspection queries

### Log Format & Introspection
- **D-13:** `-v` flag for inline routing rationale during execution
- **D-14:** Structured JSONL log with full context: complexity score, scoring mode used, history lookup results, model chain, final selection rationale
- **D-15:** All routing decisions logged regardless of `-v` flag (verbose just controls stdout)

### Claude's Discretion
- Specific decay function (exponential, linear, etc.) — pick what works well for the data patterns
- Threshold values for auto-upgrade triggers — start with sensible defaults, tune based on observed data
- Internal data structures for history caching — optimize for lookup speed

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 01 Artifacts
- `.planning/config.json` — Model registry, task_routing section, escalation chains, learning config
- `~/dev/.meta/bin/model-registry` — Model availability checking helper from Phase 01

### Existing Code (MVP to learn from)
- `~/dev/.meta/bin/ai-delegate` — Current organic implementation (856 lines), has task commands, fallback logic, logging

### Project Principles
- `.planning/PROJECT.md` — "Feedback closes the loop", "Autonomous by default"

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `model-registry` helper: query model metadata, check availability — keep this, routing module calls it
- `delegation-log.jsonl` format: already has outcome_fields defined in config — extend, don't replace
- Config structure: `task_routing`, `escalation`, `learning` sections already exist — routing reads these

### Established Patterns
- Python fallback for JSON parsing (no jq dependency) — maintain this
- Bash script with internal functions — decision to rewrite intentionally, but same language
- Session ID generation for log correlation — keep this pattern

### Integration Points
- `ai-delegate` is the entry point — rewrite preserves CLI interface
- `model-registry` called for availability checks
- `config.json` read for routing preferences and escalation chains
- `delegation-log.jsonl` appended for outcome logging

</code_context>

<specifics>
## Specific Ideas

- Claudeception-style learning: the routing system learns which scoring mode works best per task type and graduates autonomously
- Implementation overhead is not a constraint — do it right, the current ai-delegate is just a prototype

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-task-model-routing*
*Context gathered: 2026-04-18*
