# Current Milestone

**Version**: M001
**Title**: Multi-Model Orchestration
**Status**: Planning
**Started**: 2025-04-18

## Goal

Transform archon-gsd from a Claude-only workflow system into an intelligent multi-model orchestrator that routes tasks to the best available model, escalates failures with context, and learns from outcomes.

## Success Criteria

- [ ] Model registry with capability metadata and availability checks
- [ ] Task→model routing based on complexity, history, and cost
- [ ] Escalation detection (loops, failures, token exhaustion) with learning handoff
- [ ] z.ai and Ollama GLM-5.1 integrated as delegation targets
- [ ] Cross-model code review workflow with PR integration
- [ ] 999.x/9999.x phase conventions in config, consumed by workflows
- [ ] Outcome logging feeding back into routing improvements
