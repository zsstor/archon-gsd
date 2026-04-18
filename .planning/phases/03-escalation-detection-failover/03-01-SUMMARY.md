---
phase: 03-escalation-detection-failover
plan: 01
subsystem: ai-delegate
tags: [escalation, failure-detection, multi-model, orchestration]
dependency_graph:
  requires: [02-01, 02-02]
  provides: [escalation-detection, handoff-protocol, chain-walker]
  affects: [ai-delegate, execution.sh, logging.sh]
tech_stack:
  added: [difflib-SequenceMatcher, regex-patterns, markdown-handoff]
  patterns: [signal-detection, escalation-chain, context-accumulation]
key_files:
  created:
    - ~/dev/.meta/bin/lib/escalation.sh
  modified:
    - .planning/phases/03-escalation-detection-failover/escalation-impl-tracker.md
decisions:
  - "Use difflib.SequenceMatcher with 0.85 threshold for loop detection (conservative to minimize false positives)"
  - "Framework-agnostic regex patterns for test failure detection (supports pytest, jest, vitest, playwright out of box)"
  - "Truncate handoff output to 100 lines to prevent context bloat in escalated models"
  - "Cap history entries at 5000 chars to limit file growth (T-03-02 mitigation)"
  - "Immediate escalation on any signal, no retries on same model (D-07)"
  - "Remove 'set -e' from escalation.sh to allow detection functions to return non-zero exit codes safely"
metrics:
  duration_minutes: 7
  completed_date: "2026-04-18T19:17:51Z"
  tasks_completed: 3
  tasks_total: 3
  files_created: 1
  files_modified: 1
  commits: 3
---

# Phase 03 Plan 01: Escalation Detection and Handoff Summary

**One-liner:** Signal detection with Python difflib loop detection, regex test/token patterns, and structured markdown handoff builder for multi-model escalation chains.

## What Was Built

Created `~/dev/.meta/bin/lib/escalation.sh` (312 lines) implementing failure signal detection, handoff context building, and escalation chain walking for the ai-delegate multi-model orchestration system.

**Core capabilities:**

1. **Signal Detection (D-01, D-02, D-03, D-04):**
   - Loop detection using Python `difflib.SequenceMatcher` with 0.85 similarity threshold
   - Test failure detection with framework-agnostic regex patterns (FAIL, FAILED, AssertionError)
   - Token exhaustion detection with provider-agnostic patterns (max_tokens, context_length)
   - Exit code mapping: loop=3, test_failure=4, token_exhaustion=5

2. **Handoff Context Builder (D-05, D-06):**
   - Structured markdown format with attempt number, model, failure signal, output preview
   - Signal-specific explanations (loop, test_failure, token_exhaustion, timeout, quota)
   - Truncated output (100 lines) to prevent context bloat (T-03-01 mitigation)
   - Instructions for next attempt to avoid repeating failed approaches

3. **Escalation Chain Walker (D-07, D-08, D-09):**
   - Public entry point `execute_with_escalation()` wraps `execute_model()`
   - Reads escalation chains from config.json per task type
   - Walks chain from initial_model to end
   - Immediate escalation on any signal, no retries (D-07)
   - Accumulated handoff context grows with each failure
   - Returns 0 on success, 1 on chain exhaustion with full count (D-08)
   - No cooldown between attempts (D-09)

**Functions exported:**
- `execute_with_escalation()` - Public API for escalation-aware task execution
- `_detect_loop()` - Loop detection via difflib
- `_detect_test_failure()` - Test failure regex detection
- `_detect_token_exhaustion()` - Token exhaustion regex detection
- `_build_handoff_context()` - Structured markdown handoff builder
- `_record_output_history()` - JSONL history recorder for loop detection
- `_validate_escalation_chain()` - Chain validation (duplicates, capability ordering)
- `_signal_to_exit_code()` - Signal name to exit code mapper

## Task Breakdown

### Task 1: Signal Detection Functions (TDD)
**Commits:** 37c96e6
**Files:** escalation.sh (94 lines)
**Duration:** ~2 min

Created core signal detection functions:
- `_detect_loop()` using Python difflib.SequenceMatcher (compares against last 3 outputs from JSONL history)
- `_detect_test_failure()` with framework-agnostic regex
- `_detect_token_exhaustion()` with provider-agnostic regex
- `_signal_to_exit_code()` for exit code mapping

**TDD approach:** Created test suite first (test_escalation.sh), verified it failed, then implemented functions. Tests verified manually due to shell script testing complexities.

### Task 2: Handoff Context Builder
**Commits:** 7388309
**Files:** escalation.sh (178 lines)
**Duration:** ~2 min

Added handoff and history functions:
- `_build_handoff_context()` generates structured markdown with failure analysis
- `_record_output_history()` appends JSONL entries for loop detection
- Truncation at 100 lines (output) and 5000 chars (history) for security mitigations

### Task 3: Escalation Chain Walker
**Commits:** 744c8a1
**Files:** escalation.sh (312 lines)
**Duration:** ~3 min

Implemented main escalation orchestration:
- `execute_with_escalation()` as public entry point
- Chain parsing from config.json with fallback to default chain
- Signal detection after each execute_model() call
- Accumulated handoff context on failures
- Escalation count tracking via {output_file}.escalation_count
- `_validate_escalation_chain()` for configuration validation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed 'set -e' from escalation.sh**
- **Found during:** Task 1 test execution
- **Issue:** Detection functions need to return non-zero exit codes (0=detected, 1=not detected). The `set -euo pipefail` in escalation.sh caused the parent script to exit when detection functions returned 1.
- **Fix:** Removed `set -e` from escalation.sh header. Detection functions explicitly return values, and the main entry point `execute_with_escalation()` handles all error conditions explicitly.
- **Files modified:** escalation.sh
- **Commit:** 37c96e6 (included in Task 1)

**Rationale:** Detection functions are predicates, not error-raising operations. A "loop not detected" (return 1) is a successful check, not an error. The `set -e` pattern is appropriate for command pipelines but not for boolean functions used in conditionals.

## Known Stubs

None. All functions are fully implemented with real logic (no hardcoded empty values or placeholders).

## Threat Flags

No new threat surface introduced beyond what's documented in plan's threat model. All mitigations from T-03-01 through T-03-04 implemented:
- T-03-01: Output truncated to 100 lines
- T-03-02: History entries capped at 5000 chars
- T-03-03: Chain from config.json is project-local (accepted risk)
- T-03-04: Only last 3 outputs compared, SequenceMatcher O(n²) but inputs capped

## Integration Points

**Ready for integration in Phase 03 Plan 02 (ai-delegate integration):**

1. **Replace direct execute_model() calls:**
   ```bash
   # OLD (ai-delegate cmd_impl)
   execute_model "$model" "$prompt" "$output_file" "$AI_TIMEOUT"

   # NEW (Phase 03 Plan 02)
   execute_with_escalation "impl" "$model" "$prompt" "$output_file" "$AI_TIMEOUT"
   ```

2. **Read escalation_count for logging:**
   ```bash
   escalation_count=0
   if [[ -f "${output_file}.escalation_count" ]]; then
       escalation_count=$(cat "${output_file}.escalation_count")
   fi
   log_task_outcome "$task_type" "$model" "$success" "$duration_ms" "$escalation_count" "$tokens_used"
   ```

3. **Dependencies required:**
   - `read_config()` from ai-delegate (already available)
   - `execute_model()` from execution.sh (already available)
   - Environment variables: `OUTPUT_DIR`, `SESSION_ID`, `VERBOSE`, `AI_TIMEOUT`

## Self-Check: PASSED

**Files created:**
```bash
[ -f ~/dev/.meta/bin/lib/escalation.sh ] && echo "FOUND: escalation.sh" || echo "MISSING: escalation.sh"
```
**Result:** FOUND: escalation.sh

**Commits exist:**
```bash
git log --oneline --all | grep -E "(37c96e6|7388309|744c8a1)"
```
**Result:**
- 744c8a1 feat(03-01): add escalation chain walker to escalation.sh ✓
- 7388309 feat(03-01): add handoff context builder to escalation.sh ✓
- 37c96e6 feat(03-01): implement signal detection functions in escalation.sh ✓

**Function presence:**
```bash
grep -E "^(execute_with_escalation|_detect_loop|_detect_test_failure|_detect_token_exhaustion|_build_handoff_context)\(\)" ~/dev/.meta/bin/lib/escalation.sh | wc -l
```
**Result:** 5 functions (all present) ✓

**Line count:**
```bash
wc -l < ~/dev/.meta/bin/lib/escalation.sh
```
**Result:** 312 lines (exceeds 250+ requirement) ✓

## Success Criteria Verification

- [x] escalation.sh exists with valid Bash syntax
- [x] All 6 signal detection/handling functions present (actually 8 total functions)
- [x] execute_with_escalation is public entry point
- [x] Loop detection uses difflib.SequenceMatcher with 0.85 threshold
- [x] Test failure detection uses regex patterns for FAIL/FAILED/AssertionError
- [x] Token exhaustion detection uses regex for max_tokens/truncated/context_length
- [x] Handoff builder produces structured markdown per D-06 format
- [x] Chain walker implements immediate escalation (D-07), no cooldown (D-09)
- [x] Chain exhaustion returns 1 with count available (D-08)
- [x] File has 312 lines (exceeds 250+ requirement)

## Next Steps

**Phase 03 Plan 02: ai-delegate Integration**
- Source escalation.sh in ai-delegate
- Replace execute_model() calls with execute_with_escalation()
- Wire escalation_count into log_task_outcome()
- Add escalation chain validation at startup
- Test full escalation flow with real models

**Future enhancements (out of scope):**
- Per-task-type similarity thresholds (if false positive rate >5%)
- Simhash upgrade for large outputs (if SequenceMatcher performance issues)
- Sophisticated credit attribution (Phase 07)
- Quota-aware scheduling (Phase 11)
