---
phase: 11-automatic-quota-management
plan: 01
subsystem: quota-management
tags: [quota, failover, tier-aware, state-management]

dependency_graph:
  requires: []
  provides:
    - quota-error-parsing
    - tier-aware-failover
    - quota-state-cache
    - task-constraints
    - version-pinning
  affects:
    - escalation.sh
    - ai-delegate

tech_stack:
  added:
    - gemma-parse (local LLM wrapper)
  patterns:
    - hybrid-regex-llm-parsing
    - file-based-ttl-cache
    - tier-aware-failover

key_files:
  created:
    - ~/dev/.meta/bin/lib/quota.sh
    - ~/dev/.meta/bin/gemma-parse
  modified:
    - .planning/config.json
    - ~/dev/.meta/bin/lib/test_quota.sh

decisions:
  - Used file-based TTL cache for quota state (simpler than in-memory)
  - Fixed test_quota.sh arithmetic expansion bug blocking test suite
  - Fixed test_quota.sh pipefail issue with glob patterns
  - Used environment variables for Python heredoc parameters (safer)

metrics:
  duration: 8m 15s
  completed: 2026-04-18T23:20:00Z
  tasks: 3
  files: 5
---

# Phase 11 Plan 01: Create Quota Module Summary

Hybrid regex/LLM quota parser with tier-aware failover and file-based state cache.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create quota.sh with parsing and state functions | 7d60f75 (.meta) | quota.sh, test_quota.sh |
| 2 | Add failover and constraint functions to quota.sh | 4311f07 (.meta) | quota.sh, test_quota.sh |
| 3 | Create gemma-parse wrapper and update config.json | 457d68f (.meta), d5cd8f6 (zarchon) | gemma-parse, config.json |

## Key Outputs

### quota.sh Functions (~/dev/.meta/bin/lib/quota.sh)

**Detection & Parsing (Q-01, Q-02):**
- `_detect_quota_error()` - Detects quota errors across 4 providers
- `_parse_quota_error()` - Hybrid regex/LLM parser extracting wait time
- `_iso8601_to_seconds()` - Converts ISO8601 timestamps to seconds
- `_llm_parse_quota_error()` - Local LLM fallback via gemma-parse

**State Management (Q-06):**
- `_record_quota_state()` - Atomic file-based state write
- `_is_model_quota_limited()` - TTL-based quota check
- `_cleanup_expired_quota_state()` - Clean up expired state files
- `_get_model_tier()` - Model capability tier lookup (1=Opus, 2=Sonnet/Codex/GLM, 3=Gemini/Haiku)

**Failover & Constraints (Q-03, Q-04, Q-05):**
- `_check_task_constraint()` - Returns opus-only|tier-2-minimum|cross-family-preferred|flexible
- `_get_failover_candidates()` - Tier-aware model selection
- `_check_version_allowed()` - Model version pinning
- `_should_wait_not_failover()` - Wait vs failover decision

### gemma-parse (~/dev/.meta/bin/gemma-parse)

Local LLM wrapper using Ollama for parsing complex error messages when regex fails:
- Default model: glm-5.1:cloud
- 30s timeout for DoS mitigation
- Input truncation to 2000 chars
- Always returns valid integer (60 default)

### config.json Extensions

```json
{
  "quota_management": {
    "enabled": true,
    "max_wait_seconds": 900,
    "default_backoff_base": 2,
    "default_backoff_max": 300,
    "parse_model": "glm-5.1:cloud"
  },
  "task_routing": {
    "judgment": { "model_constraints": "opus-only" },
    "impl": { "model_constraints": "tier-2-minimum" },
    "code-review": { "model_constraints": "cross-family-preferred" }
  },
  "models": {
    "glm-zai": {
      "allowed_versions": ["glm-5.1"],
      "forbidden_versions": ["glm-4.6", "glm-4.5"]
    }
  }
}
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed test_quota.sh arithmetic expansion bug**
- **Found during:** Task 1
- **Issue:** `((TESTS_RUN++))` returns exit code 1 when incrementing from 0, triggering ERR trap
- **Fix:** Changed to `TESTS_RUN=$((TESTS_RUN + 1))` format and removed ERR trap
- **Files modified:** test_quota.sh
- **Commit:** 7d60f75

**2. [Rule 3 - Blocking] Fixed test_quota.sh pipefail with glob patterns**
- **Found during:** Task 2
- **Issue:** `ls *.quota | wc -l` with pipefail causes exit code 2 when no files exist
- **Fix:** Changed to `find -name "*.quota" | wc -l`
- **Files modified:** test_quota.sh
- **Commit:** 4311f07

**3. [Rule 3 - Blocking] Fixed test_quota.sh state isolation**
- **Found during:** Task 2
- **Issue:** Cleanup test used same QUOTA_STATE_DIR as previous tests, causing leftover files
- **Fix:** Each test uses fresh subdirectory
- **Files modified:** test_quota.sh
- **Commit:** 4311f07

## Test Results

All 20 tests pass:
- Q-01: 4 tests (Anthropic, OpenAI, Gemini, z.ai detection)
- Q-02: 5 tests (retry-after, ISO8601, z.ai reset, natural language, fallback)
- Q-03: 3 tests (same-tier, no-downgrade, excludes-current)
- Q-04: 2 tests (opus-only, flexible)
- Q-05: 2 tests (allowed, forbidden)
- Q-06: 4 tests (record, is-limited, ttl-expired, cleanup)

## Threat Mitigations Applied

| Threat ID | Mitigation |
|-----------|------------|
| T-11-01 | Input truncation to 2000 chars before parsing |
| T-11-02 | Atomic write pattern (tmp file + mv), numeric validation |
| T-11-03 | 30s timeout on Ollama calls |

## Self-Check: PASSED

**Files exist:**
- FOUND: /home/zzs/dev/.meta/bin/lib/quota.sh
- FOUND: /home/zzs/dev/.meta/bin/gemma-parse
- FOUND: /home/zzs/dev/zarchon/.planning/config.json

**Commits exist:**
- FOUND: 7d60f75 (Task 1)
- FOUND: 4311f07 (Task 2)
- FOUND: 457d68f (Task 3 - .meta)
- FOUND: d5cd8f6 (Task 3 - zarchon)
