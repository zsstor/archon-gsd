---
phase: 11
slug: automatic-quota-management
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash test suite (custom, no external framework) |
| **Config file** | None — tests are standalone scripts |
| **Quick run command** | `bash ~/dev/.meta/bin/lib/test_quota.sh` |
| **Full suite command** | `bash ~/dev/.meta/bin/lib/test_escalation.sh && bash ~/dev/.meta/bin/lib/test_quota.sh` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash ~/dev/.meta/bin/lib/test_quota.sh`
- **After every plan wave:** Run `bash ~/dev/.meta/bin/lib/test_escalation.sh && bash ~/dev/.meta/bin/lib/test_quota.sh`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 11-00-01 | 00 | 0 | Q-01..Q-06 | — | N/A | fixture | Create test_quota.sh | ❌ W0 | ⬜ pending |
| 11-00-02 | 00 | 0 | Q-01 | — | N/A | fixture | Create mock error responses | ❌ W0 | ⬜ pending |
| 11-01-01 | 01 | 1 | Q-01 | T-11-01 | Sanitize error before logging | unit | `test_quota.sh::test_detect_quota_*` | ❌ W0 | ⬜ pending |
| 11-01-02 | 01 | 1 | Q-02 | — | N/A | unit | `test_quota.sh::test_parse_quota_*` | ❌ W0 | ⬜ pending |
| 11-01-03 | 01 | 1 | Q-03 | — | N/A | unit | `test_quota.sh::test_failover_candidates` | ❌ W0 | ⬜ pending |
| 11-01-04 | 01 | 1 | Q-04 | — | N/A | unit | `test_quota.sh::test_constraint_*` | ❌ W0 | ⬜ pending |
| 11-01-05 | 01 | 1 | Q-05 | — | N/A | unit | `test_quota.sh::test_version_pinning` | ❌ W0 | ⬜ pending |
| 11-01-06 | 01 | 1 | Q-06 | T-11-02 | Validate state files, atomic writes | unit | `test_quota.sh::test_quota_state_*` | ❌ W0 | ⬜ pending |
| 11-02-01 | 02 | 2 | Q-01..Q-06 | — | N/A | integration | `test_escalation.sh::test_quota_integration` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `~/dev/.meta/bin/lib/test_quota.sh` — test suite for quota.sh functions (Q-01 through Q-06)
- [ ] `~/dev/.meta/bin/lib/fixtures/quota_errors/` — mock error response files for each provider
- [ ] `~/dev/.meta/bin/lib/test_escalation.sh` — update existing tests for quota integration

*Wave 0 creates test infrastructure before implementation begins.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real quota exhaustion handling | Q-02 | Requires triggering actual API rate limit | Use Gemini free tier (easy to hit limits), verify auto-wait and retry |
| Overnight hang recovery | Q-02 | Long-running scenario | Simulate by setting short quota reset, verify process resumes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
