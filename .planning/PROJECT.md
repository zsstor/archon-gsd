# archon-gsd

Faithful GSD-2 replication on Archon with intelligent multi-model orchestration.

## Vision

A workflow system where the right model handles each task — delegating simple work to cost-effective models, escalating complex work to capable ones, and learning from outcomes to improve routing over time.

## Core Principles

1. **Models don't review their own code** — cross-model verification is mandatory
2. **Config over hardcode** — conventions live in `.planning/config.json`, not scattered across YAMLs
3. **Escalation with learnings** — when a model fails, the escalation carries context about what was tried
4. **Feedback closes the loop** — outcomes feed back into routing decisions

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
- `999.x`: Cleanup backlog — non-blocking issues that need attention but aren't urgent
- `9999.x`: Parking lot — ideas awaiting prioritization into sequential phases
