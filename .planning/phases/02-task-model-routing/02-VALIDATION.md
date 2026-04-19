---
phase: 02
slug: task-model-routing
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-18
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bats (Bash Automated Testing System) 1.11+ |
| **Config file** | none — Wave 0 installs if testing desired |
| **Quick run command** | `bats tests/routing.bats` |
| **Full suite command** | `bats tests/*.bats` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `shellcheck ~/dev/.meta/bin/ai-delegate` (if installed)
- **After every plan wave:** Run `bats tests/*.bats` (if installed and tests written)
- **Before `/gsd-verify-work`:** Manual smoke test — `ai-delegate status` and `ai-delegate impl "test task" -v`
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | D-09 | — | N/A | manual-only | Visual inspection of lib/ structure | N/A | ⬜ pending |
| 02-01-02 | 01 | 1 | D-01, D-04 | — | N/A | unit | `bats tests/routing.bats -f "scoring modes"` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | D-05 | — | N/A | unit | `bats tests/routing.bats -f "time decay"` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 2 | D-14 | — | N/A | unit | `bats tests/logging.bats -f "schema"` | ❌ W0 | ⬜ pending |
| 02-01-05 | 01 | 2 | D-13 | — | N/A | smoke | `ai-delegate impl "test" -v 2>&1 \| grep -q "rationale"` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `npm install -g bats` — install Bats if unit testing desired (optional)
- [ ] `tests/routing.bats` — stubs for D-01, D-04, D-05 (complexity scoring, score range, time decay)
- [ ] `tests/logging.bats` — stubs for D-14 (JSONL schema validation)
- [ ] `sudo apt install shellcheck` — static analysis (optional)

*Decision: Testing is optional for MVP. Manual smoke tests sufficient. Defer automated tests to DEBT.1 if time-constrained.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Module separation | D-09 | Structural check, not behavioral | Verify `lib/routing.sh`, `lib/execution.sh`, `lib/logging.sh` exist in `~/dev/.meta/bin/lib/` |
| Clean CLI interface | D-08 | UX evaluation | Run `ai-delegate --help` and verify consistent subcommand structure |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
