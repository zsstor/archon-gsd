# Phase 11: Automatic Quota Management - Context

**Gathered:** 2026-04-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Autonomous quota handling — parse quota/rate-limit errors, wait for replenishment, and fail over to non-exhausted models without human intervention. The system should gracefully wait and auto-resume rather than requiring manual restarts.

</domain>

<decisions>
## Implementation Decisions

### Quota Error Parsing
- **D-01:** Hybrid parsing approach — regex first (fast path for common patterns like `retry-after`, `429`, `rate.limit.*\d+.*seconds`), fall back to local LLM for complex natural language messages
- **D-02:** Local LLM must be truly local (not subject to API quota itself) — use GLM-5.1 via Ollama or Gemma 4, whichever is available
- **D-03:** Primary goal is extracting the reset timestamp from error responses — this drives the wait duration

### Wait vs Failover Logic
- **D-04:** Quality-first failover — only fail to same-tier or higher capability models. Never downgrade.
- **D-05:** Model capability tiers:
  - Tier 1 (Planning/Judgment): Opus
  - Tier 2 (Implementation): Sonnet, GLM-5.1, Codex
  - Tier 3 (Simple/Scaffold): Gemini, Haiku
- **D-06:** Prefer graceful waiting over failover to lower tier — waiting preserves quality, downgrading loses it
- **D-07:** Cross-tier failover rules:
  - Fail UP: Always OK (Gemini → Sonnet, GLM → Opus)
  - Fail ACROSS (same tier): Usually OK (Sonnet ↔ GLM-5.1, Gemini ↔ Haiku)
  - Fail DOWN: Not OK (Opus → Gemini would be quality loss)

### Graceful Waiting
- **D-08:** Sleep in-process — keep the session alive, preserve state in memory, wait for quota recovery, retry automatically
- **D-09:** Parse reset timestamp from error response, sleep until that timestamp, then retry
- **D-10:** No complex state management — if process restarts, try again (either succeeds or gets fresh timestamp)

### Task-Model Constraints
- **D-11:** Planning/Architecture tasks require Opus — wait indefinitely rather than downgrade
- **D-12:** Code Review special rules:
  - Codex is preferred reviewer (good at review, limited capacity)
  - Cross-family fallback: if Codex down, use GLM-5.1 (different model family) rather than Opus
  - Deferred review acceptable: if reviewed by GLM during PR, add backlog item for Codex to review post-merge
  - Enforces PROJECT.md principle: "Models don't review their own code"
- **D-13:** Implementation tasks require Tier 2 minimum (Sonnet/GLM-5.1/Codex) — can shuffle within tier, don't drop to Gemini/Haiku for real implementation
- **D-14:** Tier 3 (Gemini/Haiku) is fine for additive parallel passes, supplementary coverage, simple scaffolding — not primary model for critical work

### Opus Meta-Role
- **D-15:** Opus identifies inflection points where full code reviews (premortem, gap analysis, edge case analysis) are appropriate
- **D-16:** Opus inserts these as forcing mechanisms at critical junctures — meta-layer role beyond just execution

### Claude's Discretion
- Specific regex patterns for each provider's quota error format
- Exponential backoff defaults if timestamp parsing fails
- Exact sleep granularity (poll every N seconds vs. sleep exact duration)
- Log verbosity during wait periods

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 03 Artifacts (Escalation Foundation)
- `.planning/phases/03-escalation-detection-failover/03-CONTEXT.md` — Escalation decisions D-01 through D-12, including "quota-aware scheduling deferred to Phase 11"
- `~/dev/.meta/bin/lib/escalation.sh` — Current escalation chain walker, exit code 2 for quota
- `~/dev/.meta/bin/lib/execution.sh` — `_check_quota_error()` function with basic pattern matching

### Config Structure
- `.planning/config.json` — `escalation.chain`, `task_routing`, `models` sections
- `.planning/config.json` `models.<provider>.metadata` — Token limits, capabilities per model

### Project Principles
- `.planning/PROJECT.md` — "Models don't review their own code", "Autonomous by default"

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `_check_quota_error()` in `execution.sh:241-254`: Basic pattern matching for quota errors — extend with timestamp extraction
- `execute_with_escalation()` in `escalation.sh:210-342`: Chain walker handles exit code 2, needs quota-aware wait logic injected
- Exit code convention: 2 = quota error (already established)
- Config `escalation.chain` per task type: existing structure for model ordering

### Established Patterns
- Python fallback for complex parsing (JSON, text analysis) — maintain this
- Exit code semantics: 0=success, 1=failure, 2=quota, 124=timeout, 127=unavailable
- Session ID correlation across logs

### Integration Points
- `execute_with_escalation()` is the insertion point — add wait-before-failover logic here
- `lib/quota.sh` new module for parsing and wait logic
- Local LLM wrapper (gemma-parse or reuse glm-ollama) for complex error parsing

</code_context>

<specifics>
## Specific Ideas

- The pain point is overnight hangs — Claude hits quota at 2am, process stalls, user wakes up to lost progress. System should gracefully wait and auto-resume.
- Codex has strict capacity limits and is specifically better at review than generation — preserve for review tasks
- Cross-family review matters: Anthropic models shouldn't review Anthropic output. If Codex unavailable, GLM-5.1 is better fallback than Opus because different model family.
- Deferred review pattern: if critical PR reviewed by non-Codex during quota, add backlog item for Codex to review post-merge
- Model tiering is approximate and subject to validation/iteration — not hard rules, but reasonable starting point

</specifics>

<deferred>
## Deferred Ideas

- **Benchmarking framework** — semi-regular benchmarks of available models by task type to validate tier assignments. Belongs in Phase 07 (Claudeception Feedback Loop) or future milestone.
- **Parallel additive passes** — using Gemini in parallel with Codex for critical code/SEO coverage. Interesting but orthogonal to core quota management.

</deferred>

---

*Phase: 11-automatic-quota-management*
*Context gathered: 2026-04-18*
