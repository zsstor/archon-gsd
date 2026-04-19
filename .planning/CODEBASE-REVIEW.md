---
reviewed: 2026-04-19T14:10:00Z
reviewer: Codex (o3)
scope: full_codebase
files_reviewed:
  - ~/dev/.meta/bin/lib/routing.sh
  - ~/dev/.meta/bin/lib/escalation.sh
  - ~/dev/.meta/bin/lib/quota.sh
  - ~/dev/.meta/bin/lib/logging.sh
  - ~/dev/.meta/bin/lib/execution.sh
  - ~/dev/.meta/bin/ai-delegate
findings:
  critical: 1
  warning: 7
  info: 2
  total: 10
status: issues_found
---

# Full Codebase Review Report

**Reviewed:** 2026-04-19T14:10:00Z
**Reviewer:** Codex (o3)
**Scope:** Full codebase review of multi-model orchestration libraries

## Summary

Reviewed six shell scripts comprising the ai-delegate orchestration system. Found 10 issues: 1 critical security vulnerability, 7 warnings (correctness/robustness), and 2 informational items.

The highest-risk issue is unsafe Python heredoc interpolation in `routing.sh` that could enable arbitrary Python execution. Other significant findings include `set -e` failure path bugs, incorrect outcome attribution after escalation, and missing file locking for concurrent operations.

---

## Critical Issues

### CR-01: Command Injection via Unquoted Python Heredocs

**File:** `~/dev/.meta/bin/lib/routing.sh:336-356, 438-488`

**Issue:** Two Python heredocs use unquoted `<<EOF` and interpolate shell variables directly into Python source (`'$DELEGATION_LOG'`, `'$task_type'`). `DELEGATION_LOG` is derived from `PROJECT_ROOT`, which is explicitly environment-controlled in `ai-delegate`; a crafted value containing quotes/newlines can break out of the Python string literal and execute arbitrary Python.

**Fix:** Switch both blocks to `<<'EOF'` and pass all dynamic values via environment variables, as done elsewhere in the codebase.

---

## Warnings

### WR-01: set -e Breaks Failure Path Handling

**File:** `~/dev/.meta/bin/ai-delegate:249-260, 322-333, 387-398, 439-450`

**Issue:** `ai-delegate` runs with `set -e`, but these command handlers call `execute_with_escalation` directly. If it returns non-zero, the shell exits before `exit_code=$?`, outcome logging, and user-facing error handling run. That makes failure paths incomplete and inconsistent.

**Fix:** Wrap the call in `if execute_with_escalation ...; then exit_code=0; else exit_code=$?; fi` or temporarily `set +e` around the call.

---

### WR-02: Incorrect Outcome Attribution After Escalation

**File:** `~/dev/.meta/bin/ai-delegate:260, 333, 398, 450` and `~/dev/.meta/bin/lib/escalation.sh:389-394`

**Issue:** Task outcomes are logged against the initial routed model, not the final model that actually succeeded after escalation. This poisons historical failure-rate data and can mis-train routing decisions.

**Fix:** Have `execute_with_escalation` return/persist the final model used, then pass that model to `log_task_outcome`.

---

### WR-03: Codex Model Selection Ignored

**File:** `~/dev/.meta/bin/lib/execution.sh:74-76, 130-138`

**Issue:** Codex-family routing is ignored. `execute_model` accepts `codex|o3|gpt-5.4`, but `_run_codex_backend` always executes `codex exec --model o3`. That is a correctness bug in model selection.

**Fix:** Pass the selected model into `_run_codex_backend` and map aliases explicitly.

---

### WR-04: JSONL Logging Without File Locking

**File:** `~/dev/.meta/bin/lib/logging.sh:44, 95, 361, 404, 313-316, 505-506`

**Issue:** JSONL appends and log rotation happen without file locking. In `parallel` mode or multiple concurrent invocations, entries can be lost, interleaved, or written to the wrong file during `mv`/`gzip`.

**Fix:** Protect appends and rotations with `flock` on a per-log lock file, or centralize logging through a single writer.

---

### WR-05: Silent Logging Failures

**File:** `~/dev/.meta/bin/lib/logging.sh:44-45, 95-96, 361-404`

**Issue:** Logging failures are silently discarded with `|| true`. If Python serialization fails or disk writes fail, routing history disappears with no signal, degrading later decisions and making debugging hard.

**Fix:** Emit a warning to stderr at minimum; preferably fail the current operation when required audit logs cannot be written.

---

### WR-06: Task Type Inconsistency (review vs code-review)

**File:** `~/dev/.meta/bin/lib/quota.sh:365-367` and `~/dev/.meta/bin/ai-delegate:419-450, 711`

**Issue:** Quota/task-constraint logic expects task type `code-review`, but `ai-delegate` uses `review`. Review tasks therefore bypass their intended constraint/failover policy and any `task_routing.code-review` config.

**Fix:** Normalize on one task type everywhere; `code-review` is the one already encoded in quota/config comments.

---

### WR-07: Config Update Race Condition

**File:** `~/dev/.meta/bin/lib/routing.sh:371-410`

**Issue:** `_upgrade_scoring_mode` does a read-modify-write of the shared config file without locking. Concurrent invocations can overwrite each other's updates, losing scoring-mode changes.

**Fix:** Lock the config file during the update, or move mutable routing state into a separate locked state file.

---

## Info

### IN-01: Broken jq Fallback Chain

**File:** `~/dev/.meta/bin/lib/routing.sh:101-106`

**Issue:** The jq expression in `_get_model_chain` does not actually fall back to `.task_routing.impl.models` because the input context has already been piped to `.task_routing[$tt]`. In the jq path, missing task entries fall straight to `["gemini-flash"]`.

**Fix:** Rewrite as `(.task_routing[$tt] | if type=="object" then .models else . end) // .task_routing.impl.models // ["gemini-flash"]`.

---

### IN-02: Unescaped Handoff Context

**File:** `~/dev/.meta/bin/lib/escalation.sh:139-163`

**Issue:** `_build_handoff_context` injects raw prior model output into a markdown heredoc without escaping markdown fences/content. This is not shell command injection, but it can let failed-model output reshape the next model's prompt and cause misleading handoffs.

**Fix:** Escape triple backticks and other fence-like content, or attach the previous output as a quoted/encoded block.

---

## Recommendations

1. **Immediate (CR-01):** Fix the Python heredoc injection in routing.sh before any further deployments
2. **High Priority (WR-01, WR-02):** Fix set -e handling and outcome attribution to ensure correct logging
3. **Medium Priority (WR-03 through WR-07):** Address model selection, locking, and consistency issues
4. **Low Priority (IN-01, IN-02):** Clean up jq fallback and handoff escaping

---

_Reviewed: 2026-04-19T14:10:00Z_
_Reviewer: Codex (o3)_
_Scope: full_codebase_
