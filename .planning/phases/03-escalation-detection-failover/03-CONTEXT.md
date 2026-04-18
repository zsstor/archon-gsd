# Phase 03: Escalation Detection + Failover - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Detect when a model is failing or looping, and escalate to a more capable model with context about what was tried. The escalation system feeds into learning while preserving full logs for future analysis.

</domain>

<decisions>
## Implementation Decisions

### Escalation Signal Detection
- **D-01:** Loop detection uses output similarity — hash last N outputs, trigger if similarity exceeds threshold. Catches semantic loops, not just exact matches.
- **D-02:** Test failure detection parses test output — look for framework patterns (FAIL, FAILED, AssertionError). Works with common frameworks out of the box.
- **D-03:** Token exhaustion uses output pattern matching — parse error messages for max_tokens, truncated, context_length patterns. Works across providers.
- **D-04:** Existing signals preserved: explicit_failure (non-zero exit), quota (exit code 2 from execution.sh), timeout (exit code 124)

### Handoff Protocol
- **D-05:** Handoff bundle contains full attempt history — original prompt + each model's output + failure signals. The new model sees everything tried.
- **D-06:** Handoff format is structured markdown:
  ```
  ## Previous Attempts
  ### Attempt 1 (gemini-flash)
  Output: ...
  Failure: loop detected
  ```
  Human-readable and model-friendly.

### Escalation Behavior
- **D-07:** Escalate immediately on any signal — no retries on same model. Any detected signal (loop/failure/quota/timeout) triggers immediate escalation.
- **D-08:** When chain exhausted, fail with full history — return failure with all attempt history logged. Human can review what was tried.
- **D-09:** No cooldown between escalation attempts — escalate immediately to maximize throughput. Quota management is Phase 11's concern.

### Feedback Integration
- **D-10:** Log with penalty weight — each escalation counts as a weighted failure in the model's history for that task type. Affects future routing.
- **D-11:** Credit final model only — the model that succeeds gets +1 success; failed models already got -1 each. Clean accounting.
- **D-12:** Preserve full escalation logs — separate from learning aggregation. Raw JSONL captures everything; learning uses simplified view. Future analysis (Phase 07+) can replay logs with sophisticated attribution.

### Claude's Discretion
- Similarity threshold for loop detection (start with ~0.85, tune based on observed false positives)
- Hashing algorithm for output comparison (simhash, minhash, or simple substring matching)
- Penalty weight for escalation failures vs regular failures
- Log retention policy (how long to keep verbose escalation logs)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 02 Artifacts
- `.planning/phases/02-task-model-routing/02-CONTEXT.md` — Routing architecture decisions (D-08 through D-15), modular design
- `~/dev/.meta/bin/lib/execution.sh` — Exit codes already defined (0=success, 1=failure, 2=quota, 124=timeout, 127=not available)
- `~/dev/.meta/bin/lib/logging.sh` — Outcome logging structure

### Config Structure
- `.planning/config.json` — `escalation` section with signals and chains already defined

### Project Principles
- `.planning/PROJECT.md` — "Escalation with learnings", "Feedback closes the loop"

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `execution.sh._check_quota_error()`: Already detects quota patterns, returns exit code 2
- `execution.sh._handle_timeout()`: Returns exit code 124 on timeout
- `logging.sh.log_task_outcome()`: Records success/failure with duration, escalation_count field exists
- Config `escalation.signals` and `escalation.chain`: Structure defined, ready to consume

### Established Patterns
- Exit code convention: 0/1/2/124/127 — extend, don't replace
- JSONL logging with session_id correlation — escalation events join via session_id
- Python fallback for JSON parsing — maintain this

### Integration Points
- `ai-delegate` main loop needs escalation wrapper around `execute_model()` calls
- `logging.sh` extended with `log_escalation_event()` for verbose chain logging
- Handoff context builder generates markdown from attempt history
- Learning system reads simplified view; raw logs preserved separately

</code_context>

<specifics>
## Specific Ideas

- Output similarity can start simple (substring matching or line-by-line diff ratio) and upgrade to simhash later if needed
- Handoff markdown format should be appendable — each attempt adds a section, not rewrites
- Consider a `--dry-run` flag that shows what escalation would do without executing

</specifics>

<deferred>
## Deferred Ideas

- **Sophisticated credit attribution** — distinguishing "model failed fair task" from "router gave impossible task" belongs in Phase 07 (Claudeception Feedback Loop)
- **Quota-aware scheduling** — waiting for quota recovery and intelligent failover is Phase 11 (Automatic Quota Management)

</deferred>

---

*Phase: 03-escalation-detection-failover*
*Context gathered: 2026-04-18*
