# Setup

Getting this bundle running on a fresh machine. Target platform: Linux / WSL2 / macOS.

## 1. Install Archon CLI

```bash
mkdir -p ~/.local/bin
curl -fsSL https://archon.diy/install | INSTALL_DIR=~/.local/bin bash
export PATH="$HOME/.local/bin:$PATH"     # add to ~/.bashrc or ~/.zshrc too
archon version
```

Expect `Archon CLI v0.3.6` or later. Checksum is verified automatically by the
installer. The default install path is `/usr/local/bin` which needs sudo — the
`INSTALL_DIR=~/.local/bin` override keeps it user-local.

## 2. Install this bundle into your project

```bash
cd /path/to/your/project
git clone https://github.com/adcadvance/archon-gsd.git /tmp/archon-gsd
cp -r /tmp/archon-gsd/.archon .
archon workflow list | grep zsd-         # expect 18 workflows listed
```

The `.archon/workflows/` directory can live alongside (or replace) whatever's
already in your project. Archon discovers workflows by walking up from CWD.

## 3. Bootstrap Archon auth (skip the interactive wizard)

Archon needs a Claude auth token at `~/.archon/.env`. If you already have
Claude Code working on this machine, you can reuse its OAuth token — no need
to run `archon setup`:

```bash
umask 077
mkdir -p ~/.archon
TOKEN=$(jq -r '.claudeAiOauth.accessToken' ~/.claude/.credentials.json)
cat > ~/.archon/.env <<EOF
CLAUDE_USE_GLOBAL_AUTH=false
CLAUDE_CODE_OAUTH_TOKEN=$TOKEN
EOF
chmod 600 ~/.archon/.env
```

Token expires per `expiresAt` in `~/.claude/.credentials.json` (usually months
out). Re-run the snippet above when it does.

If you don't have Claude Code on this machine, run `archon setup --spawn`
instead — it opens a new terminal window for the interactive wizard.

## 4. ⚠️ Run Archon from a non-Claude-Code terminal

**Do not run `archon workflow run ...` from inside a Claude Code session
terminal.** It will deadlock silently (v0.3.6) or error at 60s with a
misleading link to issue #1067 (v0.3.7+ / dev branch). The cause is that
Archon spawns a `claude` CLI subprocess via the Claude Agent SDK, and a nested
`claude` subprocess deadlocks on the parent session's IPC.

Stripping `CLAUDECODE`, `CLAUDE_CODE`, `CLAUDE_CODE_ENTRYPOINT`,
`CLAUDE_CODE_EXECPATH` env vars does NOT fix it — the nesting detection uses
lower-level mechanisms (sockets, file descriptors, PID tree).

**Instead, use one of:**

- **Plain terminal** (gnome-terminal, iTerm, Windows Terminal, bare WSL shell,
  SSH session) — just run `archon workflow run ...` directly.
- **`archon serve` pattern** — start `archon serve` once in a plain terminal,
  then invoke workflows via HTTP from anywhere (including inside Claude Code).

See the skill `archon-claude-code-nesting-deadlock` in `~/.claude/skills/` for
full diagnostics.

## 5. Smoke test

From a plain terminal in this repo (or any repo you want to use the bundle
on):

```bash
cd /path/to/your/project
archon workflow run zsd-status ""        # read-only dashboard, minimal AI call
```

Expected: a dashboard that says "MILESTONE none active" and prints a
bootstrap hint. If you get a response within ~10 seconds, auth works and the
bundle is functional.

To actually start using it:

```bash
archon workflow run zsd-new-milestone "v1.0 — initial milestone"
```

This starts the interactive Q&A flow documented in [README.md](./README.md).

## 6. Known issues (v0.3.6)

- **#1067**: fixed in PR #1092 on dev branch, not yet released. Only affects
  `.env` precedence when you have a `.env` file in CWD with CLAUDE_* keys
  that shadow `~/.archon/.env`. Most users are unaffected.
- **`archon serve`**: Slack/Telegram/Discord platform adapters are hardcoded
  off in v0.3.6 (`skipPlatformAdapters: true`). Fixed on dev. Doesn't affect
  `zsd-*` workflows — we only use the CLI invocation path.
- **Loop-node model routing**: Archon silently drops per-node `model:` on
  loop nodes. This bundle works around that by declaring model at the
  workflow top level for affected files (zsd-execute, zsd-discuss,
  zsd-new-milestone, zsd-autonomous). Non-loop nodes still honor per-node
  `model:`.

## Troubleshooting

- **"Command not found: archon"** — add `~/.local/bin` to PATH.
- **"Detected CLAUDECODE=1" warning** — you're in a Claude Code session;
  switch to a plain terminal. See step 4.
- **Silent hang on `archon workflow run`** — also the CC-nesting deadlock.
  Confirm with:
  ```bash
  python3 -c "
  import sqlite3, pathlib
  con = sqlite3.connect(pathlib.Path.home()/'.archon/archon.db')
  for r in con.execute('SELECT event_type, step_name, created_at FROM remote_agent_workflow_events ORDER BY created_at DESC LIMIT 5'):
      print(r)"
  ```
  If you see `node_started` without a matching `node_completed` / `node_failed`
  / `message_received`, you have the nesting deadlock. Re-run from a plain
  terminal.
- **Auth token expired** — regenerate:
  ```bash
  claude                     # any claude invocation refreshes the token
  # then re-run step 3 to update ~/.archon/.env
  ```
- **Workflow validation errors on discovery** — run
  `archon validate workflows` for detailed per-node errors. The common pitfalls
  are wrong `trigger_rule` enum values (`one_success` not `any_success`) and
  per-node model fields on loop nodes (move to workflow level).

## References

- [Archon docs](https://archon.diy/)
- [Archon GitHub](https://github.com/coleam00/Archon)
- [Issue #1067 — dotenv leak + hang + serve hardcode](https://github.com/coleam00/Archon/issues/1067)
