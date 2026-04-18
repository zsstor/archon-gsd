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
| 08 | Local-Only Mode | 05 | Medium |
| 09 | Autonomous DEBT Processing | 02, 05, 08 | High |
| 10 | Autonomous Issue Processing | 09 | Medium |
| 11 | Automatic Quota Management | 03 | High |

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

**Goal**: Intelligent routing system with complexity scoring (keyword/keyword+files/full modes), time-decayed history learning, and clean module architecture (routing.sh, execution.sh, logging.sh).

**Requirements:** D-01 through D-15

**Plans:** 2 plans

Plans:
- [x] 02-01-PLAN.md — Create module libraries (routing.sh, execution.sh, logging.sh)
- [x] 02-02-PLAN.md — Rewrite ai-delegate CLI with modules and -v flag

**Deliverables**:
- Complexity scoring heuristics (keywords, file count, test presence, etc.)
- History check: has this task type failed on cheaper models before?
- Extend `ai-delegate` to consume registry and apply routing logic
- Expose routing decision in logs for introspection

**Key Files**:
- `~/dev/.meta/bin/ai-delegate` (UPDATE)
- `~/dev/.meta/bin/lib/routing.sh` (CREATE)
- `~/dev/.meta/bin/lib/execution.sh` (CREATE)
- `~/dev/.meta/bin/lib/logging.sh` (CREATE)
- `.planning/config.json` — `task_routing` and `scoring_defaults` sections (UPDATE)

---

## Phase 03: Escalation Detection + Failover

**Intent**: Detect when a model is failing or looping, and escalate to a more capable model with context about what was tried.

**Goal**: Failure detection (loop/test-failure/token-exhaustion), structured markdown handoff protocol, and escalation chain walking with feedback integration.

**Requirements:** D-01 through D-12

**Plans:** 2 plans

Plans:
- [ ] 03-01-PLAN.md — Create escalation.sh module (signal detection, handoff builder, chain walker)
- [ ] 03-02-PLAN.md — Integrate escalation into ai-delegate + extend logging.sh

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
- `~/dev/.meta/bin/lib/escalation.sh` (CREATE)
- `~/dev/.meta/bin/lib/logging.sh` (UPDATE)
- `.planning/config.json` — `escalation` section (EXISTS)
- `.planning/escalation-log.jsonl` (CREATE)

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
  - Non-blockers with decisions → DEBT.x cleanup phase
- Integration with existing `review-pr` skill logic

**Key Files**:
- `.archon/workflows/gsd-review-pr.yaml` (CREATE)
- `.planning/config.json` — `review` section (CREATE)

---

## Phase 06: Phase Conventions

**Intent**: Make DEBT.x, PARK.x, and WANT.x conventions config-driven so workflows don't hardcode magic strings.

**Deliverables**:
- Phase conventions in config:
  ```json
  {
    "phase_conventions": {
      "cleanup_prefix": "DEBT",
      "backlog_prefix": "PARK",
      "issues_prefix": "WANT",
      "decimal_suffix_start": 1,
      "scope": "milestone"
    }
  }
  ```
- Update workflows that reference phase conventions to read from config
- Document lifecycle: DEBT.x manual increment, PARK.x/WANT.x complete on promotion

**Key Files**:
- `.planning/config.json` (UPDATE)
- `~/.claude/skills/review-pr/SKILL.md` (UPDATE) — reference config for routing
- `.planning/PROJECT.md` (UPDATE) — document conventions

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

## Phase 08: Local-Only Mode

**Intent**: Support projects without GitHub repos by providing local fallbacks for all GH-dependent workflows.

**Deliverables**:
- Config flag for GitHub mode:
  ```json
  {
    "github": {
      "enabled": true,
      "fallback": "local"
    }
  }
  ```
- Local fallbacks:
  - `gsd-review-pr` → `gsd-review-branch` (diff against main, REVIEW.md output)
  - `gh pr create` → skip, document in artifact
  - `gh pr comment` → append to local file
- Every `gh` command has a local fallback path

**Key Files**:
- `.planning/config.json` (UPDATE) — github section
- `.archon/workflows/gsd-review-pr.yaml` (UPDATE) — local mode branch
- `~/dev/.meta/bin/local-pr` (CREATE) — local PR simulation

---

## Phase 09: Autonomous DEBT Processing

**Intent**: Use cheap async models to autonomously work DEBT items to a reviewable state.

**Flow**:
1. Invoke `gsd-process-debt` (manual or scheduled)
2. Cheap model (Haiku/Gemini/GLM) picks a DEBT.x item
3. Implements fix on a branch
4. Creates draft PR
5. Delegates review to Codex
6. Output: Draft PR with review comments, ready for human merge

**Deliverables**:
- New workflow: `.archon/workflows/gsd-process-debt.yaml`
- Integration with draft PR creation
- Codex review delegation
- Stops before merge — human reviews final

**Key Files**:
- `.archon/workflows/gsd-process-debt.yaml` (CREATE)
- `.planning/config.json` — `autonomous` section (CREATE)

---

## Phase 10: Autonomous Issue Processing

**Intent**: Triage GitHub issues into WANT.x planning artifacts using cheap models.

**Flow**:
1. Invoke `gsd-process-issues`
2. Fetch open issues: `gh issue list --state open --search "-label:autotriaged"`
3. For each issue → create `WANT.x` planning artifact
4. Cheap model does triage: complexity estimate, affected files, draft approach
5. Add `autotriaged` label to processed issues
6. Output: `WANT.1-issue-42/WANT.1-TRIAGE.md` ready for review

**Deliverables**:
- New workflow: `.archon/workflows/gsd-process-issues.yaml`
- WANT.x phase convention support
- `autotriaged` label management
- Triage artifact template

**Key Files**:
- `.archon/workflows/gsd-process-issues.yaml` (CREATE)
- `.planning/config.json` — `issues` section (CREATE)

---

## Parallelization Notes

- Phases 01, 04, 06 can start in parallel (minimal dependencies)
- Phase 02 needs 01
- Phase 03 needs 02
- Phase 05 needs 02 + 04
- Phase 07 needs 03 + 05
- Phase 08 needs 05 (review workflow exists before adding local mode)
- Phase 09 needs 02, 05, 08 (routing, review, local fallback all available)
- Phase 10 needs 09 (same pattern, just different source)

Suggested execution order for serial work: 01 → 06 → 04 → 02 → 03 → 05 → 07 → 08 → 09 → 10 → 11

---

## Phase 11: Automatic Quota Management

**Intent**: Autonomous quota handling via local LLM (Gemma 4) that parses quota/rate-limit errors, waits for replenishment, and fails over to non-exhausted models — making the system truly self-healing without human intervention.

**Requirements**:
- **Q-01**: Quota error detection — parse timeout, 429, rate-limit responses across all backends
- **Q-02**: Auto-retry with backoff — local LLM determines wait time from error message, resubmits automatically
- **Q-03**: Intelligent failover — when one model exhausts quota, cascade to available models based on task compatibility
- **Q-04**: Task-specific constraints — some tasks (complex planning) locked to Opus-only; others can cascade freely
- **Q-05**: Model version pinning — config to restrict acceptable model versions per provider (e.g., z.ai → GLM-5.1 only, never GLM-4.6)
- **Q-06**: Quota status tracking — in-memory state of which models are currently quota-limited and estimated recovery time

**Signals for failover eligibility**:
- Task type from `task_routing` config (impl, scaffold, review, etc.)
- Current model's task constraint (Opus-only vs. flexible)
- Available models with unexpired quota
- Cost tier preference (prefer cheaper if task allows)

**Local LLM role (Gemma 4)**:
- Parse natural language error messages to extract wait times
- Decide: wait-and-retry vs. failover to different model
- Maintain quota state across session
- Minimal footprint — runs locally, no API costs

**Deliverables**:
- Quota parser module in `lib/quota.sh`
- Model constraint config: `task_routing.<type>.model_constraints: ["opus-only" | "flexible"]`
- Model pinning config: `models.<provider>.allowed_versions: ["glm-5.1"]`
- Gemma 4 integration for error parsing and decision making
- Quota state tracking with TTL-based recovery

**Key Files**:
- `~/dev/.meta/bin/lib/quota.sh` (CREATE) — quota parsing, state, recovery
- `~/dev/.meta/bin/gemma-parse` (CREATE) — local LLM wrapper for error parsing
- `.planning/config.json` — `quota_management`, `model_constraints`, `model_pinning` sections (UPDATE)
- `~/dev/.meta/bin/ai-delegate` (UPDATE) — integrate quota handling into execution loop

---

## Backlog

### Phase 999.1: Parallel Session Orchestration (BACKLOG)

**Goal:** Support multiple concurrent execution sessions with git worktrees. Consolidate 5-terminal workflow to 1-2 terminals. Human inflection points (approvals, completions, decisions) bubble up to a planning terminal while execution continues in background.

**Key Features:**
- Git worktree support for isolated parallel work branches
- Background execution with status bubbling to main terminal
- Human decision points queue and surface when needed
- Wave-level parallelization (multiple plans execute simultaneously)
- Session management (pause, resume, switch focus)

**Requirements:** TBD
**Plans:** 0 plans

Plans:
- [ ] TBD (promote with /gsd-review-backlog when ready)
