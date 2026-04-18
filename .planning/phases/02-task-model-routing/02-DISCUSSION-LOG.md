# Phase 02: Task→Model Routing - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 02-task-model-routing
**Areas discussed:** Complexity Scoring, History Lookup, Routing Decision Flow, Log Format & Introspection

---

## Complexity Scoring

### Scoring Mode Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Keyword heuristics only | Pattern match task descriptions. Simple, fast, no file I/O. | |
| Keyword + file count | Add ref: file count. More files = higher complexity. | |
| Full analysis | Keywords + file count + AST complexity + test presence. | |

**User's choice:** Implement all three as options with claudeception-style learning/feedback. Start with one, graduate to more as we optimize.

**Notes:** User emphasized that each task type should graduate autonomously — "that's how devs would do it."

### Auto-Upgrade Trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Failure rate threshold | Upgrade when >X% of cheap-model attempts fail within last N tasks. | |
| Escalation count | Upgrade when escalations exceed threshold. | |
| Both | Track failure rate AND escalation count. Upgrade on either signal. | ✓ |

**User's choice:** Both (Recommended)

### Score Format

| Option | Description | Selected |
|--------|-------------|----------|
| Numeric 0-100 | Normalized score. Easy to set thresholds, compare across modes. | ✓ |
| Tier buckets only | low/medium/high/critical. Simpler but less granular. | |

**User's choice:** Numeric 0-100 (Recommended)

---

## History Lookup

### History Window Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Recent window only | Only consider last N tasks. Fast lookup, adapts to recent changes. | |
| Time-decayed weights | All history, recent failures weighted more heavily. | ✓ |
| Task-type specific windows | Different window sizes per task type. | |

**User's choice:** Time-decayed per task type. User clarified: "that's irrespective of overhead" — implementation complexity not a constraint.

### History Fields

| Option | Description | Selected |
|--------|-------------|----------|
| Success + escalation only | Did it work? How many retries? | |
| All outcome fields | Success, escalation_count, tokens_used, duration_ms. | ✓ |

**User's choice:** All outcome fields (Recommended)

---

## Routing Decision Flow

### Architecture

| Option | Description | Selected |
|--------|-------------|----------|
| Single route_task() function | One function in ai-delegate: takes task_type + description + context, returns best model. | |
| Separate router script | New task-router script alongside model-registry. | |
| Inline in each command | Keep routing in cmd_impl, cmd_scaffold, etc. | |
| Standalone task-router with thin CLI | task-router handles intelligence, ai-delegate becomes thin wrapper. | |
| Library + multiple CLIs | Core routing logic as a library. Most reusable. | |
| Single smart CLI | Rewrite ai-delegate with intentional design, clean separation. | ✓ |

**User's choice:** Single smart CLI (Recommended)

**Notes:** User emphasized: "ai-delegate was organic vs intentional. don't anchor / do it right. think of that as a functional prototype / mvp"

---

## Log Format & Introspection

| Option | Description | Selected |
|--------|-------------|----------|
| Verbose flag + structured log | -v flag shows routing rationale inline. All decisions logged to JSONL. | ✓ |
| Structured log only | Silent routing, all introspection via log analysis. | |
| Separate explain command | ai-delegate explain shows what routing WOULD do. | |

**User's choice:** Verbose flag + structured log (Recommended)

---

## Claude's Discretion

- Specific decay function implementation
- Initial threshold values for auto-upgrade triggers
- Internal data structures for history caching

## Deferred Ideas

None — discussion stayed within phase scope
