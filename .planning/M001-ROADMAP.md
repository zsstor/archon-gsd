# M001 Roadmap — Multi-Model Orchestration

## Phase Overview

| Phase | Title | Depends On | Complexity |
|-------|-------|------------|------------|
| 01 | Model Registry + Config Schema | — | Medium |
| 02 | Task→Model Routing | 01 | Medium |
| 03 | Escalation Detection + Failover | 02 | High |
| 04 | z.ai + Ollama Integration | 01 | Medium |
| 05 | Cross-Model Review Workflow | 02, 04 | High |
| 06 | Phase Conventions | 01 | Low |
| 07 | Claudeception Feedback Loop | 03, 05 | Medium |

---

## Phase 01: Model Registry + Config Schema

**Intent**: Establish a central registry of available models with capability metadata, so routing decisions have structured data to work with.

**Deliverables**:
- Extend `.planning/config.json` with `models` section
- Each model entry: provider, endpoint, capabilities, cost tier, availability check
- Add z.ai and Ollama entries alongside existing Gemini/Codex/Claude
- Schema validation for config (JSON Schema or runtime check)

**Key Files**:
- `.planning/config.json` (UPDATE)
- `.archon/lib/model-registry.sh` or similar (CREATE)

---

## Phase 02: Task→Model Routing

**Intent**: Given a task description, route it to the best available model based on complexity, task type, and history.

**Deliverables**:
- Complexity scoring heuristics (keywords, file count, test presence, etc.)
- History check: has this task type failed on cheaper models before?
- Extend `ai-delegate` to consume registry and apply routing logic
- Expose routing decision in logs for introspection

**Key Files**:
- `~/dev/.meta/bin/ai-delegate` (UPDATE)
- `.planning/config.json` — `task_routing` section (UPDATE)

---

## Phase 03: Escalation Detection + Failover

**Intent**: Detect when a model is failing or looping, and escalate to a more capable model with context about what was tried.

**Signals**:
- Explicit failure (non-zero exit, error output)
- Loop detection (N similar outputs in a row)
- Test failures after implementation
- Token budget exhausted

**Deliverables**:
- Escalation detector in `ai-delegate`
- Handoff protocol: bundle attempt history + failure signal into context for next model
- Configurable escalation chain per task type
- Log escalation events for feedback loop

**Key Files**:
- `~/dev/.meta/bin/ai-delegate` (UPDATE)
- `.planning/config.json` — `escalation` section (CREATE)

---

## Phase 04: z.ai + Ollama Integration

**Intent**: Add GLM-5.1 as a delegation target via both z.ai (cloud) and Ollama (local).

**Deliverables**:
- z.ai API wrapper (direct, not through OpenCode)
- Ollama CLI wrapper (`ollama run glm-5.1`)
- Response normalization to common format
- Add both to fallback chain in config
- Availability checks (is Ollama running? is z.ai reachable?)

**Key Files**:
- `~/dev/.meta/bin/ai-delegate` (UPDATE)
- `~/dev/.meta/bin/zai-run` (CREATE) — z.ai wrapper
- `~/dev/.meta/bin/ollama-run` (CREATE) — Ollama wrapper

---

## Phase 05: Cross-Model Review Workflow

**Intent**: Enforce "models don't review their own code" by delegating code review to a different model (default: Codex), posting findings to PR, and routing issues.

**Deliverables**:
- New workflow: `.archon/workflows/gsd-review-pr.yaml`
- Finding classification: BLOCKING vs NON-BLOCKING
- PR comment posting via `gh pr comment`
- Routing:
  - Blockers + straightforward non-blockers → feed back to original model (or escalate)
  - Non-blockers with decisions → 999.x cleanup phase
- Integration with existing `review-pr` skill logic

**Key Files**:
- `.archon/workflows/gsd-review-pr.yaml` (CREATE)
- `.planning/config.json` — `review` section (CREATE)

---

## Phase 06: Phase Conventions

**Intent**: Make 999.x (cleanup) and 9999.x (backlog) conventions config-driven so workflows don't hardcode magic numbers.

**Deliverables**:
- Add `phase_conventions` to config:
  ```json
  {
    "phase_conventions": {
      "cleanup_series": 999,
      "backlog_series": 9999,
      "decimal_suffix_start": 1
    }
  }
  ```
- Update workflows that reference these conventions to read from config
- Document behavior: 999.1 → 999.2 on completion; 9999.x completes when promoted

**Key Files**:
- `.planning/config.json` (UPDATE)
- `.archon/workflows/gsd-verify.yaml` (UPDATE) — reference config for routing
- `.archon/workflows/gsd-review-pr.yaml` (UPDATE if created)

---

## Phase 07: Claudeception Feedback Loop

**Intent**: Log routing decisions and outcomes so the system learns which models succeed at which tasks.

**Deliverables**:
- Outcome logging: task type, model used, success/failure, escalation count, tokens used
- Log location: `.planning/delegation-log.jsonl` (already exists in `ai-delegate`)
- Analysis script: summarize success rates by model × task type
- Feed learnings into routing: boost/penalize models based on history
- Optional: surface learnings to user periodically

**Key Files**:
- `~/dev/.meta/bin/ai-delegate` (UPDATE) — ensure logging captures outcomes
- `~/dev/.meta/bin/delegation-stats` (CREATE) — analysis script
- `.planning/config.json` — `learning` section (CREATE)

---

## Parallelization Notes

- Phases 01, 04, 06 can start in parallel (minimal dependencies)
- Phase 02 needs 01
- Phase 03 needs 02
- Phase 05 needs 02 + 04
- Phase 07 needs 03 + 05

Suggested execution order for serial work: 01 → 06 → 04 → 02 → 03 → 05 → 07
