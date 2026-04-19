# archon-gsd

Faithful GSD-2 replication on Archon with intelligent multi-model orchestration.

## Vision

A workflow system where the right model handles each task — delegating simple work to cost-effective models, escalating complex work to capable ones, and learning from outcomes to improve routing over time.

## Core Principles

1. **Models don't review their own code** — cross-model verification is mandatory
2. **Config over hardcode** — conventions live in `.planning/config.json`, not scattered across YAMLs
3. **Escalation with learnings** — when a model fails, the escalation carries context about what was tried
4. **Feedback closes the loop** — outcomes feed back into routing decisions
5. **Autonomous by default** — if something can be done autonomously, do it:
   - Don't ask for credentials that exist in accessible config files
   - Install CLIs once, auth once — not per-request
   - Prefer programmatic access over manual steps
   - Surface decisions, not tasks that could be automated

## Model Ecosystem

| Model | Provider | Strength | Cost |
|-------|----------|----------|------|
| Claude Opus | Anthropic | Judgment, architecture, complex reasoning | High |
| Claude Sonnet | Anthropic | Bulk implementation, balanced | Medium |
| Claude Haiku | Anthropic | Trivial tasks, formatting | Low |
| Gemini 2.5 Flash | Google | Simple impl, scaffolding | Free tier |
| Codex (o3/gpt-5.4) | OpenAI | TDD cycles, code review | Medium |
| GLM-5.1 (z.ai) | Zhipu | Implementation (via cloud) | TBD |
| GLM-5.1 (Ollama) | Local | Implementation (local inference) | Free |

## Phase Conventions

- `01-99`: Sequential implementation phases
- `XX.1, XX.2, ...`: Decimal phases for remediation/hotfixes inserted mid-milestone
- `DEBT.x`: Deferred technical debt — non-blocking issues that need attention but aren't urgent
- `PARK.x`: Parking lot — ideas awaiting prioritization into sequential phases
- `WANT.x`: User wants — GitHub issues and feature requests awaiting triage

### Lifecycle

**DEBT.x (Technical Debt)**
- `DEBT.1` is a catch-all for deferred items during current milestone
- When all items in `DEBT.1` are done, close it
- Next deferral creates `DEBT.2` (manual increment)
- Milestone-scoped: lives in `.planning/milestones/M001-phases/DEBT.1-cleanup/`

**PARK.x (Parking Lot)**
- `PARK.1` holds ideas awaiting prioritization
- A `PARK.x` phase **completes when promoted** to a sequential phase (e.g., moved to phase 12)
- The promotion is the completion — no separate close action needed
- Milestone-scoped: can be promoted to current or future milestone

**WANT.x (User Wants)**
- `WANT.x` phases are auto-created from GitHub issues via `zsd-process-issues`
- Each issue gets a triage artifact: `WANT.1-issue-42/WANT.1-TRIAGE.md`
- Processed issues are labeled `autotriaged` to avoid re-processing
- A `WANT.x` phase **completes when promoted** to a sequential phase
- Issues can stay open indefinitely without re-burning tokens
