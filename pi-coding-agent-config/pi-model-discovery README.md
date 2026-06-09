# `pi-model-discovery`

Status: canonical model-discovery/update tool for Pi local/remote model providers.

Executable:

```text
~/.local/bin/pi-model-discovery
```

Target config updated by default:

```text
~/.pi/agent/models.json
```

## Common usage

Preview only:

```bash
pi-model-discovery --dry-run
```

Apply updates:

```bash
pi-model-discovery
```

Scan one provider only:

```bash
pi-model-discovery --only llama-local --dry-run
pi-model-discovery --only llama-local
```

Scan an ad-hoc provider:

```bash
pi-model-discovery --provider llama-local=llamacpp:http://127.0.0.1:4321/v1 --dry-run
```

Show optional introspection failures, such as missing `/props`:

```bash
pi-model-discovery --dry-run --verbose
```

## Safety behavior

- Running with no args writes updates for reachable providers.
- Every non-dry-run creates a timestamped backup next to `models.json` before writing, e.g. `models.json.backup.YYYYMMDD-HHMMSS`.
- After writing, the script prints a unified diff against that backup.
- Unreachable providers are skipped.
- Skipped providers are not rewritten or cleared.
- `--dry-run` never writes `models.json` and does not create a backup.
- The script preserves existing provider objects where possible, replacing only the discovered provider's `models` list and normalizing relevant provider fields.

## Provider kinds

The script infers provider kind from existing `models.json` keys/base URLs or from explicit `--provider key=kind:url` arguments.

Supported kinds:

| Kind | Discovery | Notes |
|---|---|---|
| `llamacpp` | OpenAI-compatible `/v1/models` plus optional root `/props` | Direct `llama-server`; endpoint props can override reasoning heuristics. |
| `lmstudio` | OpenAI-compatible `/v1/models` plus optional root `/props` | LM Studio may accept reasoning params but not honor them for every GGUF. |
| `ollama` | Native `/api/tags` and `/api/show` | Pi provider is still configured as OpenAI-compatible `/v1`. |
| `openai-compatible` | OpenAI-compatible `/v1/models` plus optional root `/props` | Generic fallback. |

## Reasoning/thinking rules

Core principle:

```text
endpoint evidence > model-name heuristic
```

The script first infers rough model capability from the model ID/name, then lets endpoint evidence override it.

### Qwen + direct llama.cpp

For Qwen models on direct `llama.cpp` endpoints, if the endpoint is reasoning-capable, Pi should use:

```json
"compat": {
  "thinkingFormat": "qwen-chat-template"
}
```

This makes Pi send:

```json
"chat_template_kwargs": {
  "enable_thinking": true,
  "preserve_thinking": true
}
```

instead of top-level `enable_thinking`.

### Hard no-thinking endpoints

For non-Ollama providers, the script tries root:

```text
/props
```

If props indicate:

```json
"reasoning_format": "none"
```

or:

```json
"default_generation_settings": {
  "params": {
    "reasoning_format": "none"
  }
}
```

then the generated model entry uses:

```json
"reasoning": false
```

and appends `-nothink` to the visible model name.

Example:

```json
{
  "id": "qwen36-35b-a3b-llamacpp",
  "name": "qwen36-35b-a3b-llamacpp-nothink",
  "reasoning": false
}
```

This describes the endpoint behavior, not just the underlying model family's theoretical capability.

## LM Studio distinction

LM Studio and direct `llama.cpp` can both expose OpenAI-compatible `/v1/models`, but they should not be treated the same for thinking control.

Observed for the tested Qwen GGUF:

- LM Studio accepted controls like `reasoning_effort: "none"` and `chat_template_kwargs.enable_thinking: false`, but still produced `reasoning_content`.
- Direct `llama-server` honored server/template settings and exposed useful `/props` evidence.

Therefore:

- `kind=lmstudio` Qwen defaults to `thinkingFormat: "openai"` when reasoning is enabled.
- `kind=llamacpp` Qwen uses endpoint `/props` evidence first; otherwise Qwen uses `thinkingFormat: "qwen-chat-template"`.

## Relevant notes

More detailed investigation notes:

```text
~/.local/bin/pi-coding-agent-config/qwen-llamacpp-thinking-control.md
```
