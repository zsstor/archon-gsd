# archon-gsd

A faithful [GSD-2](https://github.com/coleam00/get-shit-done-cc) workflow replication built on top of [Archon](https://archon.diy/), the YAML workflow engine for AI coding agents.

**Why this exists.** GSD-2 is the shipping-oriented planning/execution framework that turns a milestone idea into merged PRs through a disciplined roadmap → research → discuss → plan → execute → verify pipeline. Running GSD-2's native loop against the raw Anthropic API violates Claude Code's terms of service, so this bundle replays the same loop through the Claude Code SDK via Archon instead. **No innovation, no "improvements" — faithful replication of GSD-2 semantics, plus one deliberate swap: the `discuss` phase uses GSD-1's adaptive-questioning style (more conversational, more judgment per turn) instead of GSD-2's fixed multi-round script.**

Everything after discuss is fully autonomous. You lock decisions in one Claude Code window, fire a second window (CLI, Web UI, or the Archon server on another terminal), and the plan → execute → verify chain runs to completion with per-node model routing.

---

## Install

```bash
# 1. Install the Archon CLI (once, globally)
brew install coleam00/tap/archon               # macOS
curl -fsSL https://archon.diy/install.sh | sh  # Linux / WSL

# 2. Drop this bundle into your project
git clone https://github.com/<you>/archon-gsd ~/.archon-gsd
cp -r ~/.archon-gsd/.archon /path/to/your/project/

# 3. Verify
cd /path/to/your/project
archon workflow list | grep gsd-
```

You should see 18 workflows prefixed `gsd-`.

---

## GSD-2 ↔ Archon mapping

| GSD-2 surface              | archon-gsd workflow              | Interactive? | Primary model | Notes                                         |
| -------------------------- | -------------------------------- | ------------ | ------------- | --------------------------------------------- |
| `/gsd2-status`             | `gsd-status`                     | no           | haiku         | Dashboard over `.planning/`                   |
| `/gsd-new-milestone`       | `gsd-new-milestone`              | **yes**      | opus          | Requirements + roadmap bootstrap              |
| `/gsd2-research`           | `gsd-research`                   | no           | sonnet × 4    | 4 parallel researcher nodes, fan-in synth     |
| `/gsd-discuss-phase`       | `gsd-discuss`                    | **yes**      | opus          | Adaptive Q&A (GSD-1 style) — the swap         |
| `/gsd2-plan`               | `gsd-plan`                       | no           | opus          | PLAN.md with goal-backward verification       |
| `/gsd2-queue`              | `gsd-queue`                      | no           | sonnet        | Queue future milestones with `depends_on`     |
| `/gsd-execute-phase`       | `gsd-execute`                    | no           | sonnet + opus | Wave-based, per-task loop, atomic commits     |
| `/gsd-verify-work`         | `gsd-verify`                     | no           | sonnet        | UAT + goal-backward verification              |
| `/gsd-autonomous`          | `gsd-autonomous`                 | no           | mixed         | Chains plan → execute → verify in one run     |
| `/gsd-complete-milestone`  | `gsd-complete-milestone`         | no           | sonnet        | Archive + prep next version                   |
| `/gsd-cleanup`             | `gsd-cleanup`                    | no           | haiku         | Archive accumulated phase dirs                |
| `/gsd-extract-learnings`   | `gsd-extract-learnings`          | no           | sonnet        | Distill decisions, patterns, surprises        |
| `/gsd-audit-milestone`     | `gsd-audit-milestone`            | no           | opus          | Pre-archive completeness audit                |
| `/gsd-code-review`         | `gsd-code-review`                | no           | opus          | Retroactive REVIEW.md                         |
| `/gsd-ui-review`           | `gsd-ui-review`                  | no           | sonnet        | 6-pillar visual audit                         |
| `/gsd-secure-phase`        | `gsd-secure-phase`               | no           | opus          | Threat mitigation verification                |
| `/gsd-validate-phase`      | `gsd-validate-phase`             | no           | sonnet        | Retroactive Nyquist coverage                  |
| `/gsd-eval-review`         | `gsd-eval-review`                | no           | opus          | AI phase eval coverage audit                  |

The three bootstrap surfaces absent from this bundle — `/gsd-map-codebase`, `/gsd-new-project`, `/gsd-ai-integration-phase` — are out of scope for v1: they're setup-time, not pipeline-time, and are easier to run once manually in a CC session than to scaffold as workflows.

---

## Usage — two windows

GSD's operating model is: **lock decisions in Window 1, watch autonomous work in Window 2**. Archon's worktree isolation makes this clean — the autonomous run happens in `~/.archon/workspaces/<repo>/` against a throwaway clone, so Window 1 can keep working on the repo uninterrupted.

### Window 1 — interactive decision capture (main Claude Code session)

```bash
# In your project repo, in Claude Code:
archon workflow run gsd-new-milestone "v2.0 — multi-tenant auth"
# ... answer questions, capture requirements ...

archon workflow run gsd-research 01
# ... 4 researchers fan out, synthesize, commit .planning/.../RESEARCH.md ...

archon workflow run gsd-discuss 01
# ... adaptive Q&A loop — you're actively answering and steering ...
# ... when you say "ready", commits DECISIONS.md + CONTEXT.md ...
```

At this point your repo has the decision artifacts committed. Everything needed for autonomous work is on disk.

### Window 2 — autonomous execution (separate terminal, or Archon Web UI)

```bash
# In a SECOND terminal, same repo:
archon workflow run gsd-autonomous 01
# ... plan → execute → verify, no human input, model-routed per node ...
# ... on completion, a PR is open against main ...
```

Or, if you prefer the per-phase split for partial re-runs:

```bash
archon workflow run gsd-plan 01
archon workflow run gsd-execute 01
archon workflow run gsd-verify 01
```

Window 1 can keep planning the *next* phase (`gsd-discuss 02`) while Window 2 is executing phase 01. The worktree isolation guarantees they don't step on each other.

---

## Model routing

Per-node `model:` settings implement GSD-2's "heavy-judgment nodes get Opus, bulk-work nodes get Sonnet, trivial-deterministic nodes get Haiku" rule. Override the defaults by editing the individual YAML files — every node has an explicit `model:` field so you never have to guess what's running.

| Work type                                  | Default | Rationale                                               |
| ------------------------------------------ | ------- | ------------------------------------------------------- |
| Adaptive discussion, planning, architecture, audits | opus    | Judgment-dense, single-shot, cost-tolerant              |
| Research, code implementation, code review | sonnet  | Bulk coding work, parallel-safe, good cost/quality      |
| Dashboards, formatting, classification     | haiku   | Short deterministic output, latency-sensitive           |

Advanced overrides available on every node: `effort: high|max`, `thinking: {type: enabled, budgetTokens: N}`, `fallbackModel: claude-haiku`, `maxBudgetUsd: 2.50`, `sandbox: {enabled: true}`, `allowed_tools: [...]`, `skills: [...]`. See [Archon reference](https://archon.diy/guides/authoring-workflows/).

> **Known Archon constraint (as of v0.3.6):** per-node `model:` and `fallbackModel:` fields are honored on DAG nodes (`prompt:`, `bash:`, `approval:`) but **silently ignored on loop nodes**. Loop iterations run with the workflow-level default model. The bundle sets `provider: claude` at the workflow level; if you want a specific model for loop iterations (e.g., Sonnet with Opus fallback for `gsd-execute`'s Ralph loop), add `model:` at the workflow top level instead of per-node. Archon logs `loop_node_ai_fields_ignored` warnings on discovery when the per-node fields are dropped — benign, but a signal that routing isn't happening where you expect.

---

## Directory layout the workflows assume

```
<your-repo>/
├── .archon/
│   └── workflows/            # this bundle
├── .planning/                # GSD artifact tree — created/read by the workflows
│   ├── ROADMAP.md
│   ├── milestones/
│   │   └── v2.0-phases/
│   │       └── 01-multi-tenant/
│   │           ├── 01-CONTEXT.md        # <- gsd-discuss writes this
│   │           ├── 01-RESEARCH.md       # <- gsd-research writes this
│   │           ├── 01-DECISIONS.md      # <- gsd-discuss writes this
│   │           ├── 01-PLAN.md           # <- gsd-plan writes this
│   │           ├── 01-VERIFICATION.md   # <- gsd-verify writes this
│   │           └── progress.txt         # <- gsd-execute appends per task
└── ...
```

The workflows read state from disk (the `.planning/` tree) and commit their output. This is how Window 1 and Window 2 communicate — through the repo, not through in-memory state. Same pattern as GSD-1/GSD-2 native.

---

## Extension points

Because this is plain YAML, extending is mechanical:

- **Add a new phase type** — copy `gsd-plan.yaml`, rename, swap the prompt.
- **Swap the model for one step** — edit the `model:` field on that node.
- **Add a pre-flight check** — insert a `bash:` node with `depends_on: [start-of-chain]`.
- **Wire in a different test runner** — edit the `bash:` block in `gsd-verify.yaml`'s validation node.
- **Attach MCP servers** — add `mcp: .archon/mcp/servers.json` to any node.
- **Load a CC skill** — add `skills: [skill-name]` to any node.

---

## Not covered by this bundle (and why)

- **Subagent spawning.** Archon nodes can't recursively invoke other workflows. GSD-1's subagent fan-out (e.g., `gsd-codebase-mapper` spawning 4 parallel mappers) is replicated here by having multiple sibling nodes at the same DAG layer instead — same outcome, flatter graph.
- **Persistent cross-run state.** Archon runs each workflow in a fresh worktree. All state lives in committed files. If you want cross-workflow memory (e.g., "what did I learn in the last phase"), read `.planning/milestones/.../LEARNINGS.md` — `gsd-extract-learnings` writes it.
- **Approval-gate recovery.** If you reject an approval gate in `gsd-discuss`, Archon re-prompts up to the node's `max_attempts`. Beyond that, re-run the workflow.

---

## License & attribution

GSD-2 ©  Cole Medin / contributors. Archon © coleam00. This adapter is MIT licensed.
