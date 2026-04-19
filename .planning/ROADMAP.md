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
| 11 | 3/3 | Complete    | 2026-04-18 |

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

## Phase 03.1: PR 1 Review Fixes (INSERTED)

**Intent**: Fix critical issues found by Codex code review before merging PR 1.

**Goal**: Address P1 blockers (function order, set -e breaking escalation) and P2 warnings (missing log path, unsanitized routing descriptions).

**Requirements:** P1-1, P1-2, P2-1, P2-2

**Plans:** 1/1 plans complete

Plans:
- [x] 03.1-01-PLAN.md — Fix all 4 review findings (function order, errexit, log path, sanitization)

**Findings to Fix:**

| ID | Severity | Issue | File |
|----|----------|-------|------|
| P1-1 | Critical | `session_id` called before defined | ai-delegate:56 |
| P1-2 | Critical | `set -e` breaks escalation loop | escalation.sh:269 |
| P2-1 | Warning | Status command missing log path arg | ai-delegate:516 |
| P2-2 | Warning | Routing decisions not sanitized | logging.sh:30 |

**Key Files**:
- `~/dev/.meta/bin/ai-delegate` (UPDATE)
- `~/dev/.meta/bin/lib/escalation.sh` (UPDATE)
- `~/dev/.meta/bin/lib/logging.sh` (UPDATE)

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
- New workflow: `.archon/workflows/zsd-review-pr.yaml`
- Finding classification: BLOCKING vs NON-BLOCKING
- PR comment posting via `gh pr comment`
- Routing:
  - Blockers + straightforward non-blockers → feed back to original model (or escalate)
  - Non-blockers with decisions → DEBT.x cleanup phase
- Integration with existing `review-pr` skill logic

**Key Files**:
- `.archon/workflows/zsd-review-pr.yaml` (CREATE)
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
  - `zsd-review-pr` → `zsd-review-branch` (diff against main, REVIEW.md output)
  - `gh pr create` → skip, document in artifact
  - `gh pr comment` → append to local file
- Every `gh` command has a local fallback path

**Key Files**:
- `.planning/config.json` (UPDATE) — github section
- `.archon/workflows/zsd-review-pr.yaml` (UPDATE) — local mode branch
- `~/dev/.meta/bin/local-pr` (CREATE) — local PR simulation

---

## Phase 09: Autonomous DEBT Processing

**Intent**: Use cheap async models to autonomously work DEBT items to a reviewable state.

**Flow**:
1. Invoke `zsd-process-debt` (manual or scheduled)
2. Cheap model (Haiku/Gemini/GLM) picks a DEBT.x item
3. Implements fix on a branch
4. Creates draft PR
5. Delegates review to Codex
6. Output: Draft PR with review comments, ready for human merge

**Deliverables**:
- New workflow: `.archon/workflows/zsd-process-debt.yaml`
- Integration with draft PR creation
- Codex review delegation
- Stops before merge — human reviews final

**Key Files**:
- `.archon/workflows/zsd-process-debt.yaml` (CREATE)
- `.planning/config.json` — `autonomous` section (CREATE)

---

## Phase 10: Autonomous Issue Processing

**Intent**: Triage GitHub issues into WANT.x planning artifacts using cheap models.

**Flow**:
1. Invoke `zsd-process-issues`
2. Fetch open issues: `gh issue list --state open --search "-label:autotriaged"`
3. For each issue → create `WANT.x` planning artifact
4. Cheap model does triage: complexity estimate, affected files, draft approach
5. Add `autotriaged` label to processed issues
6. Output: `WANT.1-issue-42/WANT.1-TRIAGE.md` ready for review

**Deliverables**:
- New workflow: `.archon/workflows/zsd-process-issues.yaml`
- WANT.x phase convention support
- `autotriaged` label management
- Triage artifact template

**Key Files**:
- `.archon/workflows/zsd-process-issues.yaml` (CREATE)
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

**Intent**: Autonomous quota handling via local LLM that parses quota/rate-limit errors, waits for replenishment, and fails over to non-exhausted models — making the system truly self-healing without human intervention.

**Goal**: Eliminate overnight hangs by gracefully waiting for quota recovery and auto-resuming. Tier-aware failover ensures quality is never downgraded.

**Requirements:** Q-01, Q-02, Q-03, Q-04, Q-05, Q-06

**Plans:** 3/3 plans complete

Plans:
- [x] 11-00-PLAN.md — Wave 0: Create test_quota.sh and mock error fixtures
- [x] 11-01-PLAN.md — Create quota.sh module (parsing, state, failover, constraints)
- [x] 11-02-PLAN.md — Integrate quota handling into escalation.sh and ai-delegate

**Signals for failover eligibility**:
- Task type from `task_routing` config (impl, scaffold, review, etc.)
- Current model's task constraint (Opus-only vs. flexible)
- Available models with unexpired quota
- Cost tier preference (prefer cheaper if task allows)

**Local LLM role (GLM-5.1 via Ollama)**:
- Parse natural language error messages to extract wait times
- Decide: wait-and-retry vs. failover to different model
- Maintain quota state across session
- Minimal footprint — runs locally, no API costs

**Deliverables**:
- Quota parser module in `lib/quota.sh`
- Model constraint config: `task_routing.<type>.model_constraints: ["opus-only" | "flexible"]`
- Model pinning config: `models.<provider>.allowed_versions: ["glm-5.1"]`
- Local LLM integration for error parsing and decision making
- Quota state tracking with TTL-based recovery

**Key Files**:
- `~/dev/.meta/bin/lib/quota.sh` (CREATE) — quota parsing, state, recovery
- `~/dev/.meta/bin/gemma-parse` (CREATE) — local LLM wrapper for error parsing
- `.planning/config.json` — `quota_management`, `model_constraints`, `model_pinning` sections (UPDATE)
- `~/dev/.meta/bin/ai-delegate` (UPDATE) — integrate quota handling into execution loop

---

## Phase 11.1: PR 1 Review Fixes (INSERTED)

**Goal:** Fix critical and warning issues from Phase 11 code review before merging PR #1.

**Findings to Fix:**

| ID | Severity | Issue | File |
|----|----------|-------|------|
| CR-01 | Critical | Command injection in `_validate_escalation_chain` via heredoc | escalation.sh:420-442 |
| WR-02 | Warning | Race condition in history file append (use flock) | escalation.sh:199-200 |
| WR-03 | Warning | Missing python3 availability check before heredoc | quota.sh:152 |
| WR-04 | Warning | Shell variable interpolation in logging.sh Python heredocs | logging.sh:89-104 |
| WR-05 | Warning | Unbounded parallel process spawning (add MAX_PARALLEL) | ai-delegate:414-434 |

**Requirements**: R-11.1-01 through R-11.1-05
**Depends on:** Phase 11

**Plans:** 1/1 plans complete

Plans:
- [x] 11.1-01-PLAN.md — Fix all 5 review findings (CR-01, WR-02, WR-03, WR-04, WR-05)

**Key Files**:
- `~/dev/.meta/bin/lib/escalation.sh` (UPDATE - CR-01, WR-02)
- `~/dev/.meta/bin/lib/quota.sh` (UPDATE - WR-03)
- `~/dev/.meta/bin/lib/logging.sh` (UPDATE - WR-04)
- `~/dev/.meta/bin/ai-delegate` (UPDATE - WR-05)

---

## Phase 11.2: Security Pattern Remediation

**Goal:** Fix remaining command injection vulnerabilities (CR-02 through CR-05) in logging.sh and ai-delegate by applying consistent env var + quoted heredoc pattern. Also fix WR-01 (flock fd collision) and WR-02 (incomplete credential sanitization).

**Requirements**: SEC-11.2-01, SEC-11.2-02, SEC-11.2-03, SEC-11.2-04, SEC-11.2-05, SEC-11.2-06
**Depends on:** Phase 11.1

**Plans:** 2/2 plans complete

Plans:
- [x] 11.2-01-PLAN.md — Fix 5 heredoc vulnerabilities in logging.sh + expand credential sanitization
- [x] 11.2-02-PLAN.md — Fix read_config heredoc in ai-delegate + change flock fd to 9

**Findings to Fix:**

| ID | Severity | Issue | File |
|----|----------|-------|------|
| CR-02 | Critical | Command injection in `query_history` | logging.sh:131 |
| CR-03 | Critical | Command injection in `_apply_time_decay` | logging.sh:174 |
| CR-04 | Critical | Command injection in `_compute_weighted_failure_rate` | logging.sh:203 |
| CR-05 | Critical | Command injection in `read_config` | ai-delegate:107 |
| WR-01 | Warning | File descriptor 200 collision risk | escalation.sh:200 |
| WR-02 | Warning | Incomplete credential sanitization | logging.sh:266 |

**Key Files**:
- `~/dev/.meta/bin/lib/logging.sh` (UPDATE - CR-02, CR-03, CR-04, WR-02)
- `~/dev/.meta/bin/ai-delegate` (UPDATE - CR-05)
- `~/dev/.meta/bin/lib/escalation.sh` (UPDATE - WR-01)

---

## Phase 11.3: Config Schema Consistency Fix

**Goal:** Fix schema inconsistency in `task_routing` config entries where `impl`, `code-review`, and `judgment` use object format while routing/logging code expects array format. Align schema so `model_chain` is logged correctly.

**Context:** Found during PR #1 code review by Codex. The `task_routing.impl` entry changed from array to object, causing `model_chain` to be logged as object instead of array format.

**Requirements**: SCHEMA-01, SCHEMA-02, SCHEMA-03
**Depends on:** Phase 11.2

**Plans:** 1/1 plans complete

Plans:
- [x] 11.3-01-PLAN.md — Normalize config schema, create _get_model_chain helper, update ai-delegate callers

**Key Files**:
- `.planning/config.json` (UPDATE)
- `~/dev/.meta/bin/lib/routing.sh` (UPDATE)
- `~/dev/.meta/bin/ai-delegate` (UPDATE)

---

## Phase 11.4: Code Review Fixes (routing.sh + ai-delegate)

**Goal:** Address 15 code review findings from Phase 11.3 review: 2 critical security issues (command injection, unsafe .profile sourcing), 8 warnings (array bounds, non-atomic writes, missing checks), and 5 info items (error context, magic numbers, logging consistency).

**Context:** Found during Phase 11.3 code review. These are pre-existing issues in routing.sh and ai-delegate, not introduced by 11.3 changes.

**Requirements**: CR-01, CR-02, WR-01, WR-02, WR-03, WR-04, WR-05, WR-06, WR-07, WR-08
**Depends on:** Phase 11.3

**Plans:** 3 plans

Plans:
- [ ] 11.4-00-PLAN.md — Create test suites (test_routing.sh, test_delegate.sh) for TDD validation
- [ ] 11.4-01-PLAN.md — Fix routing.sh issues (CR-01, WR-01, WR-02, WR-03, WR-07)
- [ ] 11.4-02-PLAN.md — Fix ai-delegate issues (CR-02, WR-04, WR-05, WR-06, WR-08)

**Key Files**:
- `~/dev/.meta/bin/lib/routing.sh` (UPDATE — CR-01, WR-01, WR-02, WR-03, IN-02, IN-04)
- `~/dev/.meta/bin/ai-delegate` (UPDATE — CR-02, WR-04, WR-05, WR-06, WR-08, IN-01, IN-03, IN-05)

**Findings Summary**:

Critical:
- CR-01: Command injection via unescaped task_type in jq (routing.sh:55)
- CR-02: Arbitrary code execution via .profile sourcing (ai-delegate:26)

Warnings:
- WR-01: Array access without bounds check (routing.sh:242-244)
- WR-02: Non-atomic config file modification (routing.sh:358-387)
- WR-03: Python dependency without fallback (routing.sh:195,200)
- WR-04: Module source without existence check (ai-delegate:30-34)
- WR-05: Task type inconsistency "review" vs "code-review" (ai-delegate:367)
- WR-06: File read without permission check (ai-delegate:175-180)
- WR-07: Datetime parsing without error handling (routing.sh:432-434)
- WR-08: Large file inclusion in prompts (ai-delegate:318)

Info:
- IN-01: Missing error context in die() (ai-delegate:85)
- IN-02: Magic numbers for complexity thresholds (routing.sh:241-244)
- IN-03: Verbose logging inconsistency (ai-delegate:168-171)
- IN-04: Incomplete variable validation (routing.sh:162-163)
- IN-05: Unclear session ID cleanup (ai-delegate:75-78)

---

## Phase 12: GSD to Zarchon Migration

**Goal:** Convert existing GSD projects to zarchon projects, preserving work product (.planning/, ROADMAP.md, PLAN.md, SUMMARY.md, etc.) while migrating to native Archon workflow execution with zsd-* naming.

**Requirements**: D-01, D-03, D-04, D-06, D-07, D-08, D-09
**Depends on:** Phase 11.1

**Plans:** 2/2 plans complete

Plans:
- [x] 12-01-PLAN.md — Rename 18 workflow files gsd-* to zsd-*, update internal refs, add version field, update docs
- [x] 12-02-PLAN.md — Create migration detection utility (is_zarchon_migrated, is_gsd_project functions)

**Key Files**:
- `.archon/workflows/zsd-*.yaml` (RENAME from gsd-*.yaml)
- `.planning/config.json` (UPDATE — add zarchon_version field)
- `.archon/lib/migration.sh` (CREATE — detection utilities)
- `README.md` (UPDATE — zsd-* references)
- `SETUP.md` (UPDATE — zsd-* references)
- `.planning/PROJECT.md` (UPDATE — zsd-* references)

---

## Phase 12.1: PR 2 Review Fixes (INSERTED)

**Goal:** Fix two non-blocking issues found during PR #2 code review: missing models array in task_routing.review and incorrect detection order in migration_status().

**Requirements**: PR2-F1, PR2-F2
**Depends on:** Phase 12

**Plans:** 1 plan

Plans:
- [ ] 12.1-01-PLAN.md — Fix config.json review routing and migration.sh detection order

**Findings to Fix:**

| ID | Severity | Issue | File |
|----|----------|-------|------|
| PR2-F1 | Non-blocking (P2) | Missing `models` array in `task_routing.review` | .planning/config.json:195-197 |
| PR2-F2 | Non-blocking (P2) | Partial migrations classified as GSD due to check order | .archon/lib/migration.sh:64-79 |

**Key Files**:
- `.planning/config.json` (UPDATE — add models array to task_routing.review)
- `.archon/lib/migration.sh` (UPDATE — reorder detection in migration_status)

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

---

### Phase 999.2: Archon Built-in Processes Audit (BACKLOG)

**Goal:** Inspect Archon's native processes, workflows, and utilities to determine which should be adopted vs. kept separate. Evaluate overlap with GSD workflows and identify opportunities for consolidation or reuse.

**Key Questions:**
- What workflows does Archon provide natively?
- Which Archon features overlap with GSD skills?
- Are there Archon utilities we should adopt instead of custom implementations?
- Where should GSD defer to Archon vs. provide its own approach?

**Requirements:** TBD
**Plans:** 0 plans

Plans:
- [ ] TBD (promote with /gsd-review-backlog when ready)

### Phase 999.3: TDD-First Visual Regression Testing (BACKLOG)

**Goal:** Establish TDD as the default workflow for all work including UI. Build toward integration with an upcoming screenshot-based user agent plugin that validates click-depth, reachability, UI drift, dead-ends, and role-based GUI access. Create a robust red-green-monitor feedback loop where tests start red, implementation drives toward green, and regression suite catches subsequent issues.

**Key Features:**
- TDD as default workflow — tests written before implementation for all work
- Screenshot agent integration (DOM-independent visual validation)
- Click-depth and reachability validation
- UI drift detection between versions
- Dead-end detection (unreachable states, broken flows)
- Role-based GUI access validation
- Red → Green → Monitor lifecycle enforcement
- Regression testing that persists across builds

**Integration Point:** Upcoming screenshot-based user agent plugin that ignores DOM and uses visual screenshots for validation, enabling implementation-agnostic UI testing.

**Requirements:** TBD
**Plans:** 0 plans

Plans:
- [ ] TBD (promote with /gsd-review-backlog when ready)
