---
phase: 01-model-registry
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - /home/zzs/dev/zarchon/.planning/config.json
  - /home/zzs/dev/.meta/bin/model-registry
  - /home/zzs/dev/.meta/bin/ai-delegate
autonomous: true
requirements: [REG-01, REG-02, REG-03]

must_haves:
  truths:
    - "Each model in config has metadata with context_window, supports_tools, supports_images"
    - "model-registry script can list available models"
    - "model-registry script can check model availability"
    - "model-registry script can query model capabilities"
    - "ai-delegate uses registry for availability checks instead of inline logic"
    - "No regressions in existing delegation flow"
  artifacts:
    - path: "/home/zzs/dev/zarchon/.planning/config.json"
      provides: "Extended model metadata schema"
      contains: "metadata"
    - path: "/home/zzs/dev/.meta/bin/model-registry"
      provides: "Registry helper script"
      exports: ["list", "check", "get", "capabilities"]
    - path: "/home/zzs/dev/.meta/bin/ai-delegate"
      provides: "Updated delegation with registry integration"
      contains: "model-registry"
  key_links:
    - from: "/home/zzs/dev/.meta/bin/ai-delegate"
      to: "/home/zzs/dev/.meta/bin/model-registry"
      via: "source command"
      pattern: "source.*model-registry"
    - from: "/home/zzs/dev/.meta/bin/model-registry"
      to: "/home/zzs/dev/zarchon/.planning/config.json"
      via: "python3 JSON parsing"
      pattern: "python3.*json.load"
---

<objective>
Establish a central model registry with capability metadata and availability checking.

Purpose: Provide structured data for routing decisions (Phase 02) and enable per-provider availability probes before task delegation.

Output:
- Extended config.json with `metadata` sub-objects per model
- `model-registry` helper script with list/check/get/capabilities commands
- ai-delegate updated to source registry and use it for availability checks
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@/home/zzs/dev/zarchon/.planning/PROJECT.md
@/home/zzs/dev/zarchon/.planning/M001-ROADMAP.md
@/home/zzs/dev/zarchon/.planning/milestones/M001-phases/01-model-registry/01-CONTEXT.md
@/home/zzs/dev/zarchon/.planning/milestones/M001-phases/01-model-registry/01-RESEARCH.md
@/home/zzs/dev/zarchon/.planning/milestones/M001-phases/01-model-registry/01-DECISIONS.md

<interfaces>
<!-- Current config.json model structure (to extend) -->
From /home/zzs/dev/zarchon/.planning/config.json:
```json
{
  "models": {
    "<model-name>": {
      "provider": "string",
      "model_id": "string",
      "capabilities": ["array"],
      "cost_tier": "string",
      "check_command": "string|null",
      "endpoint": "string",       // Optional
      "notes": "string"           // Optional
    }
  }
}
```

<!-- ai-delegate existing Python fallback pattern (lines 74-105) -->
From /home/zzs/dev/.meta/bin/ai-delegate:
```bash
# Read config value with jq (fallback to python)
read_config() {
    local key="$1"
    local default="$2"
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$default"
        return
    fi
    local value
    if command -v jq &>/dev/null; then
        value=$(jq -r ".delegation.${key} // empty" "$CONFIG_FILE" 2>/dev/null)
    else
        value=$(python3 -c "
import json
try:
    with open('$CONFIG_FILE') as f:
        cfg = json.load(f)
    v = cfg.get('delegation', {}).get('$key')
    # ... value handling
except: pass
" 2>/dev/null)
    fi
    echo "${value:-$default}"
}
```

<!-- ai-delegate has_gemini/has_codex functions (lines 154-160) -->
```bash
has_gemini() {
    command -v gemini &>/dev/null
}
has_codex() {
    command -v codex &>/dev/null
}
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Extend config.json with metadata sub-objects</name>
  <files>/home/zzs/dev/zarchon/.planning/config.json</files>
  <action>
Add `metadata` sub-object to each model in config.json with technical attributes (per D-03).

For each model, add these fields to `metadata`:
- `max_input_tokens`: integer — context window size
- `max_output_tokens`: integer — max response tokens
- `supports_tools`: boolean — tool/function calling support
- `supports_images`: boolean — vision/multimodal support
- `supports_streaming`: boolean — streaming response support
- `supports_caching`: boolean — prompt caching support (Anthropic)

Use these values:
```
claude-opus:    max_input=200000, max_output=8192, tools=true, images=true, streaming=true, caching=true
claude-sonnet:  max_input=200000, max_output=8192, tools=true, images=true, streaming=true, caching=true
claude-haiku:   max_input=200000, max_output=4096, tools=true, images=true, streaming=true, caching=true
gemini-flash:   max_input=1000000, max_output=8192, tools=true, images=true, streaming=true, caching=false
codex:          max_input=128000, max_output=32768, tools=true, images=true, streaming=true, caching=false
glm-zai:        max_input=128000, max_output=4096, tools=true, images=false, streaming=true, caching=false
glm-ollama:     max_input=128000, max_output=4096, tools=true, images=false, streaming=true, caching=false
```

Keep existing fields unchanged. Keep `models.*` and `delegation.*` namespaces separate (per D-04).
  </action>
  <verify>
    <automated>python3 -c "import json; c=json.load(open('/home/zzs/dev/zarchon/.planning/config.json')); assert all('metadata' in m for m in c['models'].values()), 'missing metadata'; assert all('max_input_tokens' in m['metadata'] for m in c['models'].values()), 'missing max_input_tokens'; print('OK')"</automated>
  </verify>
  <done>All 7 models in config.json have `metadata` sub-objects with all 6 technical attributes.</done>
</task>

<task type="auto">
  <name>Task 2: Create model-registry helper script</name>
  <files>/home/zzs/dev/.meta/bin/model-registry</files>
  <action>
Create `/home/zzs/dev/.meta/bin/model-registry` as a bash script with Python fallback (no jq dependency per constraint).

Commands to implement:
1. `list` — List all model names from config
2. `check <model>` — Check if model is available (exit 0=available, 1=unavailable)
3. `get <model> <property>` — Get a model property (provider, model_id, cost_tier, etc.)
4. `capabilities <model>` — List capabilities for a model
5. `metadata <model> [field]` — Get metadata (all JSON or specific field)

Implementation details:
- Use CONFIG_FILE from PROJECT_ROOT detection (same pattern as ai-delegate)
- Python fallback for all JSON parsing
- Provider-specific availability checks in `check`:
  - anthropic: always return 0 (API-based, assume available)
  - google: `command -v gemini`
  - openai: `command -v codex`
  - ollama: curl http://localhost:11434/api/tags with timeout, then check model in list
  - zhipu: check ZHIPU_API_KEY env var present AND curl reachable (graceful failure per D-01)
- If model has explicit `check_command`, use that instead of provider default
- Cache registry JSON in /tmp/.model-registry-$$ for session performance

Script structure:
```bash
#!/usr/bin/env bash
set -euo pipefail

# PROJECT_ROOT detection (same as ai-delegate)
# CONFIG_FILE derivation
# Python fallback functions: _load_registry, _get_model_prop, _list_models
# Provider availability checks: _check_anthropic, _check_google, _check_openai, _check_ollama, _check_zhipu
# Command dispatcher: list, check, get, capabilities, metadata
```

Make executable: chmod +x
  </action>
  <verify>
    <automated>/home/zzs/dev/.meta/bin/model-registry list | grep -q claude-opus && /home/zzs/dev/.meta/bin/model-registry get claude-opus provider | grep -q anthropic && /home/zzs/dev/.meta/bin/model-registry capabilities claude-opus | grep -q judgment && echo "OK"</automated>
  </verify>
  <done>model-registry script exists, is executable, and list/get/capabilities commands work correctly.</done>
</task>

<task type="auto">
  <name>Task 3: Update ai-delegate to use model-registry</name>
  <files>/home/zzs/dev/.meta/bin/ai-delegate</files>
  <action>
Update `/home/zzs/dev/.meta/bin/ai-delegate` to source and use model-registry for availability checks.

Changes:
1. Add source statement near top (after set -euo pipefail, before config section):
   ```bash
   # Source model registry helper
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "${SCRIPT_DIR}/model-registry"
   ```

2. Replace `has_gemini()` and `has_codex()` functions with registry-based checks:
   ```bash
   has_gemini() {
       model_registry_check gemini-flash
   }
   has_codex() {
       model_registry_check codex
   }
   ```
   (Or simply call `model-registry check <model>` directly in calling code)

3. Update `cmd_status()` to show all registered models and their availability:
   - Loop through `model-registry list`
   - For each, call `model-registry check <model>`
   - Display status with provider info

4. Keep the existing `read_config()` function for `delegation.*` namespace (per D-04 — both namespaces must work)

5. Ensure existing commands (impl, test-pass, scaffold, tdd-cycle, etc.) still work — no regressions.

Preserve all existing functionality. The integration adds registry-based availability, it doesn't replace the delegation routing logic (that's Phase 02).
  </action>
  <verify>
    <automated>/home/zzs/dev/.meta/bin/ai-delegate status 2>&1 | grep -q "Available" && /home/zzs/dev/.meta/bin/ai-delegate help | grep -q "impl" && echo "OK"</automated>
  </verify>
  <done>ai-delegate sources model-registry, uses it for availability checks, status command shows all models, existing commands work.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| config.json | Hand-edited JSON, trusted but could have syntax errors |
| model-registry | Reads config, executes check_command from config |
| External APIs | Ollama localhost, z.ai cloud endpoint |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-01 | Tampering | check_command | accept | User controls config.json; eval is deliberate for custom checks |
| T-01-02 | Info Disclosure | ZHIPU_API_KEY | mitigate | Never log API key; only check presence and probe endpoint |
| T-01-03 | Denial of Service | availability checks | mitigate | Use curl --connect-timeout 2 for all network probes |
| T-01-04 | Spoofing | Ollama API | accept | localhost only; assumes local trust boundary |
</threat_model>

<verification>
After all tasks complete:
1. Config validation:
   ```bash
   python3 -c "import json; json.load(open('/home/zzs/dev/zarchon/.planning/config.json')); print('Config valid')"
   ```

2. Registry commands work:
   ```bash
   /home/zzs/dev/.meta/bin/model-registry list
   /home/zzs/dev/.meta/bin/model-registry check gemini-flash
   /home/zzs/dev/.meta/bin/model-registry get claude-opus cost_tier
   /home/zzs/dev/.meta/bin/model-registry capabilities codex
   /home/zzs/dev/.meta/bin/model-registry metadata claude-sonnet max_input_tokens
   ```

3. ai-delegate integration:
   ```bash
   /home/zzs/dev/.meta/bin/ai-delegate status
   /home/zzs/dev/.meta/bin/ai-delegate help
   ```

4. No regressions (verify existing routing logic unchanged):
   ```bash
   AI_TOOL=auto /home/zzs/dev/.meta/bin/ai-delegate impl "test task" --dry-run 2>&1 || echo "dry-run not implemented, manual verify"
   ```
</verification>

<success_criteria>
- [ ] config.json has `metadata` sub-object for all 7 models
- [ ] Each metadata has: max_input_tokens, max_output_tokens, supports_tools, supports_images, supports_streaming, supports_caching
- [ ] model-registry script is executable and works without jq
- [ ] model-registry list shows all 7 models
- [ ] model-registry check returns correct availability for gemini-flash and codex
- [ ] model-registry get/capabilities/metadata return correct values
- [ ] ai-delegate status shows all models with availability
- [ ] ai-delegate impl/test-pass/scaffold commands still work
- [ ] No jq dependency anywhere in new code
</success_criteria>

<output>
After completion, create `/home/zzs/dev/zarchon/.planning/milestones/M001-phases/01-model-registry/01-SUMMARY.md`
</output>
