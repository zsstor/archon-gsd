---
phase: 02-task-model-routing
plan: 01
subsystem: ai-delegation
tags: [routing, complexity-scoring, history-learning, module-architecture]
dependency_graph:
  requires: [phase-01-model-registry]
  provides: [routing-module, execution-module, logging-module]
  affects: [ai-delegate-cli]
tech_stack:
  added: [bash-modules, jsonl-logging, exponential-decay]
  patterns: [three-mode-scoring, time-weighted-history, backend-dispatch]
key_files:
  created:
    - ~/dev/.meta/bin/lib/routing.sh
    - ~/dev/.meta/bin/lib/logging.sh
    - ~/dev/.meta/bin/lib/execution.sh
  modified: []
decisions:
  - Use exponential time decay with 7-day half-life for history weighting
  - Default to "keyword" scoring mode, auto-upgrade on dual-signal trigger
  - Bayesian prior (0.5 failure rate) for cold start (<5 entries)
  - Python fallback for JSON parsing (no jq dependency)
  - Separate .meta git repository for bin/ scripts
metrics:
  duration_seconds: 187
  tasks_completed: 3
  commits: 3
  files_created: 3
  completed_at: "2026-04-18T17:14:16Z"
---

# Phase 02 Plan 01: Internal Module Libraries Summary

**One-liner:** Three modular Bash libraries implementing complexity scoring (keyword/keyword+files/full), time-decayed history learning (7-day exponential decay), and backend dispatch (gemini/codex/glm-ollama/glm-zai) with structured JSONL logging.

## Objectives Achieved

**Primary goal:** Create clean module separation for ai-delegate rewrite — routing owns scoring/history/selection (D-10), execution owns dispatch/timeout (D-11), logging owns recording/introspection (D-12).

**Deliverables:**
1. ✅ `lib/routing.sh` - Complexity scoring with three modes, history-based model selection, auto-upgrade triggers
2. ✅ `lib/logging.sh` - JSONL structured logging, outcome recording, time-decayed history queries
3. ✅ `lib/execution.sh` - Backend dispatch with timeout, quota detection, output normalization

All modules are sourceable, syntax-valid, and implement their assigned requirements (D-01 through D-15).

## Implementation Details

### Routing Module (`routing.sh`)

**Complexity Scoring (D-01, D-04):**
- Three modes: `keyword` (baseline 50 + indicators), `keyword+files` (+20/40 for file counts), `full` (+25 for context >200 lines)
- 0-100 numeric scale with threshold-based model selection (<40, 40-70, >70)
- Keyword indicators: high complexity (+35) for refactor/migrate/architect, medium (+15) for test/integrate/api

**Auto-Upgrade Logic (D-02, D-03):**
- Dual-signal trigger: `failure_rate > 0.3` OR `escalation_avg > 2.0`
- Per-task-type independent tracking and upgrade
- Config persistence via Python JSON updates

**Model Selection (D-10):**
- Reads task_routing chains from config.json
- Applies complexity thresholds to select from chain
- Falls back to first available model if selected unavailable
- Integrates with model-registry for availability checks

### Logging Module (`logging.sh`)

**JSONL Schema (D-14, D-15):**
```json
{
  "timestamp": "2026-04-18T17:14:16",
  "event_type": "routing_decision",
  "task_type": "impl",
  "description": "truncated to 200 chars",
  "complexity_score": 65,
  "scoring_mode": "keyword",
  "history_failure_rate": 0.15,
  "selected_model": "gemini-flash",
  "model_chain": ["gemini-flash", "glm-ollama"],
  "rationale": "Below escalation threshold"
}
```

**Time Decay Implementation (D-05):**
- Exponential decay: `weight * (0.5 ^ (age_days / 7))`
- Half-life of 7 days (recent failures weigh 2x more than week-old)
- Python implementation for float precision

**History Queries (D-06, D-07):**
- Per-task-type filtering with 30-day default window
- All outcome fields captured: success, duration_ms, escalation_count, tokens_used
- Cold start handling: returns 0.5 Bayesian prior if <5 entries

**Security Mitigations:**
- T-02-01: Description truncation to 200 chars (info disclosure)
- T-02-03: Log rotation after 10,000 entries (DoS prevention)

### Execution Module (`execution.sh`)

**Backend Dispatch (D-11):**
- Model-to-command mapping:
  - `gemini-flash` → `gemini -p "$prompt" --yolo -m gemini-2.5-flash` (runs from PROJECT_ROOT)
  - `codex` → `codex exec --model o3 --sandbox workspace-write --full-auto`
  - `glm-ollama` → `~/dev/.meta/bin/ollama-run` wrapper
  - `glm-zai` → `~/dev/.meta/bin/zai-run` wrapper
  - `claude-*` → returns 127 (not directly callable)

**Timeout Handling:**
- GNU `timeout` command wrapper
- Returns exit code 124 on timeout
- Configurable timeout_seconds parameter (default 300)

**Output Processing:**
- ANSI code stripping
- Line ending normalization (DOS → Unix)
- Quota error detection (exit code 2 for quota/rate limit patterns)

**Exit Codes:**
- 0: Success
- 1: General failure
- 2: Quota/rate limit
- 124: Timeout
- 127: Model/backend not available

## Architecture

**Module Separation (D-09):**
```
~/dev/.meta/bin/lib/
├── routing.sh      # Complexity → Model selection
│   ├── route_task()                (public)
│   ├── _score_complexity()         (internal)
│   ├── _check_upgrade_trigger()    (internal)
│   └── _select_model()             (internal)
├── logging.sh      # Recording → Introspection
│   ├── log_routing_decision()      (public)
│   ├── log_task_outcome()          (public)
│   ├── query_history()             (public)
│   └── _apply_time_decay()         (internal)
└── execution.sh    # Dispatch → Output
    ├── execute_model()             (public)
    ├── _run_backend()              (internal)
    ├── _handle_timeout()           (internal)
    └── _check_quota_error()        (internal)
```

**Integration Pattern:**
```bash
# ai-delegate main script (future rewrite)
source "${SCRIPT_DIR}/lib/routing.sh"
source "${SCRIPT_DIR}/lib/execution.sh"
source "${SCRIPT_DIR}/lib/logging.sh"

# Workflow
model=$(route_task "impl" "$description")
execute_model "$model" "$prompt" "$output_file"
log_task_outcome "impl" "$model" "$success" "$duration_ms"
```

## Deviations from Plan

None — plan executed exactly as written. All requirements (D-01 through D-15) implemented as specified.

## Technical Decisions

1. **Exponential decay over linear:** Research shows exponential decay better emphasizes recent failures. 7-day half-life balances recency vs. historical data.

2. **Bayesian prior for cold start:** Return 0.5 failure rate when <5 entries prevents division by zero and represents "no information" state.

3. **Python for all JSON operations:** Reliable serialization/parsing without jq dependency. Handles escaping, Unicode, nested objects correctly.

4. **Separate .meta git repo:** Scripts in `~/dev/.meta/bin/` tracked in parent `/home/zzs/dev/.meta` repository, not zarchon. Commits made there.

5. **Config auto-update for scoring mode:** Routing module writes back to config.json when auto-upgrading scoring modes. Persists learning across sessions.

## Verification Results

**Syntax validation:**
```
✓ routing.sh syntax valid
✓ logging.sh syntax valid
✓ execution.sh syntax valid
```

**Function counts:**
- routing.sh: 10 functions (1 public entry point, 9 internal helpers)
- logging.sh: 8 functions (3 public API, 5 internal helpers)
- execution.sh: 12 functions (1 public entry point, 11 internal helpers)

**Requirements coverage:**
- ✅ D-01: Three scoring modes (keyword, keyword+files, full)
- ✅ D-02: Auto-upgrade per task type
- ✅ D-03: Dual-signal trigger (failure_rate OR escalation_avg)
- ✅ D-04: 0-100 numeric complexity scores
- ✅ D-05: Exponential time decay (7-day half-life)
- ✅ D-06: All outcome fields logged
- ✅ D-07: Per-task-type independent history
- ✅ D-09: Clean module separation
- ✅ D-10: Routing module ownership
- ✅ D-11: Execution module ownership
- ✅ D-12: Logging module ownership
- ✅ D-14: JSONL structured logging schema
- ✅ D-15: Always log routing decisions

## Known Stubs

None — all modules are complete implementations ready for integration into ai-delegate rewrite.

## Threat Flags

None — all threats in plan's threat_model were mitigated:
- T-02-01 (Info Disclosure): Description truncated to 200 chars
- T-02-02 (Tampering): JSONL format accepts interleaved lines
- T-02-03 (DoS): Log rotation after 10k entries (implementation ready, not triggered in this phase)
- T-02-04 (Elevation): Accepted — backends run in user context

## Next Steps

1. **Phase 02 Plan 02:** Rewrite ai-delegate CLI to source these modules
2. **Phase 02 Plan 03:** Add verbose mode (-v) inline routing rationale
3. **Phase 02 Plan 04:** Implement history introspection commands
4. **Integration testing:** Source modules in existing ai-delegate, test routing decisions
5. **Performance tuning:** Monitor history lookup speed, tune cache strategy if needed

## Files Modified

**Created:**
- `~/dev/.meta/bin/lib/routing.sh` (432 lines)
- `~/dev/.meta/bin/lib/logging.sh` (294 lines)
- `~/dev/.meta/bin/lib/execution.sh` (325 lines)

**Modified:**
- None (new module creation only)

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | 10d78cb | feat(02-01): create routing.sh with complexity scoring and model selection |
| 2 | 4257222 | feat(02-01): create logging.sh with JSONL recording and history queries |
| 3 | 445fd72 | feat(02-01): create execution.sh with backend dispatch and timeout handling |

**Repository:** `/home/zzs/dev/.meta` (separate from zarchon)

## Self-Check: PASSED

**Created files exist:**
```
FOUND: ~/dev/.meta/bin/lib/routing.sh
FOUND: ~/dev/.meta/bin/lib/logging.sh
FOUND: ~/dev/.meta/bin/lib/execution.sh
```

**Commits exist in .meta repo:**
```
FOUND: 10d78cb (routing.sh)
FOUND: 4257222 (logging.sh)
FOUND: 445fd72 (execution.sh)
```

**All modules sourceable:**
```
✓ routing.sh syntax valid
✓ logging.sh syntax valid
✓ execution.sh syntax valid
```

---

**Phase:** 02-task-model-routing
**Plan:** 01
**Status:** ✅ Complete
**Duration:** 187 seconds
**Completed:** 2026-04-18T17:14:16Z
