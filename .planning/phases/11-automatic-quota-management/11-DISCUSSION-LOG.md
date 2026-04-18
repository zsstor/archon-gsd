# Phase 11: Automatic Quota Management - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-18
**Phase:** 11-automatic-quota-management
**Areas discussed:** Gemma 4 / local LLM role, Wait vs failover logic, Task-model constraints, Quota state tracking

---

## Gemma 4 / Local LLM Role

| Option | Description | Selected |
|--------|-------------|----------|
| Regex first, LLM fallback | Try pattern matching first (fast), fall back to local LLM for complex messages | ✓ |
| Local LLM only | Always use local LLM for all quota parsing — consistent but adds latency | |
| Regex only | Pattern matching only — fast and no dependencies, may miss edge cases | |

**User's choice:** Regex first, LLM fallback (Recommended)

**Notes:** User clarified that Gemma was proposed because local models aren't subject to quota themselves. The specific model (Gemma 4 vs GLM-5.1) is Claude's discretion — key constraint is "must be local inference."

---

## Wait vs Failover Logic

**User's input (free-text discussion):**

> "Most important likely is quality. Falling over from Sonnet to GLM-5.1 is fine. Opus to Gemini is not."

User described model tiers:
- Opus >>> Sonnet > GLM-5.1 >>> Gemini/Haiku
- Failing UP (to more capable) is always OK
- Failing DOWN is usually not OK
- Graceful waiting is MORE important than smart failover — pain point is overnight hangs where Claude quota-stalls and user loses hours of progress

| Option | Description | Selected |
|--------|-------------|----------|
| Sleep in-process | Keep the process alive, sleep for recovery time, then retry | ✓ |
| Checkpoint and exit | Write state to disk, exit with special code, external scheduler resumes | |
| Hybrid | Sleep for <5min waits, checkpoint for longer | |

**User's choice:** Sleep in-process (simpler)

---

## Task-Model Constraints

**User's input (free-text discussion):**

Key points:
- Some tasks ARE fine for Haiku/Gemini (additive parallel passes, supplementary coverage)
- Codex for review is "somewhat hard rule" — good at review, limited capacity
- Cross-family review important: if Codex down, use GLM-5.1 (different model family) rather than Opus
- Deferred review acceptable: add backlog item for Codex to review post-merge if it was unavailable during PR
- Opus identifies inflection points where full reviews (premortem, gap analysis, edge case analysis) are appropriate

**Notes:** User emphasized cross-model/cross-family review to avoid "Opus reviewing Opus' own work" — aligns with PROJECT.md principle "Models don't review their own code."

---

## Quota State Tracking

| Option | Description | Selected |
|--------|-------------|----------|
| Keep it simple | Parse reset timestamp from error, sleep until then, retry | ✓ |
| Add backoff heuristics | If timestamp parsing fails, use exponential backoff | |

**User's choice:** Keep it simple

**Notes:** User clarified that quota responses typically include reset timestamps. The implementation should extract that timestamp and sleep until then — no complex state management needed.

---

## Claude's Discretion

- Specific local LLM model (GLM-5.1 vs Gemma 4)
- Regex patterns for each provider's error format
- Default backoff if timestamp parsing fails
- Sleep granularity

## Deferred Ideas

- Benchmarking framework for model tier validation
- Parallel additive passes (Gemini alongside Codex for extra coverage)
