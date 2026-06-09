# Qwen llama.cpp / Pi thinking-control notes

Status: tested locally on 2026-06-09.

## Context

Goal: use Qwen3.6 MTP via local `llama-server` and allow Pi to influence thinking when possible. If not possible, keep thinking disabled by default.

Tested model/launcher:

- Launcher: `~/dev-external/start-mtp.sh`
- Server: `~/dev-external/llama.cpp/build-arm64-apple-clang-release/bin/llama-server`
- Model: `~/.lmstudio/models/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/Qwen3.6-35B-A3B-UD-Q4_K_S.gguf`
- Endpoint tested: `http://127.0.0.1:4321/v1/chat/completions`

## Findings

### LM Studio could not disable thinking for this GGUF

LM Studio accepted several OpenAI-compatible / Qwen-ish controls, but the loaded GGUF still emitted `reasoning_content`:

- no param → `reasoning_content` present
- `reasoning_effort: "none"` → `reasoning_content` present
- `chat_template_kwargs.enable_thinking: false` → `reasoning_content` present
- top-level `enable_thinking: false` → `reasoning_content` present
- prompt-level `/no_think` → `reasoning_content` present

LM Studio warning observed:

```text
No valid custom reasoning fields found ...
Reasoning setting 'off' cannot be converted to any custom KVs.
```

Interpretation: this is a LM Studio + GGUF metadata/template-control limitation, not primarily a Pi config issue.

### Direct llama-server can disable thinking

Adding these flags to `start-mtp.sh` disabled reasoning fully:

```bash
  --reasoning off \
  --reasoning-budget 0 \
```

Endpoint test result:

```text
server_defaults              reasoning=False content='Hello'
reasoning_effort_none        reasoning=False content='Hello'
chat_template_enable_false   reasoning=False content='Hello'
request_budget_zero          reasoning=False content='Hello'
budget_zero_with_tags        reasoning=False content='Hello'
```

Log evidence:

```text
reasoning-budget: activated, budget=0 tokens
reasoning-budget: budget=0, forcing immediately
reasoning-budget: forced sequence complete, done
```

### Better mode: default thinking off, Pi/client can opt in

`--reasoning auto --reasoning-budget 0` did **not** default to no-thinking. It still emitted reasoning by default.

The working default-off launcher form is:

```bash
  --reasoning auto \
  --chat-template-kwargs '{"enable_thinking":false}' \
```

Endpoint behavior with this launcher:

```text
default_cli_enable_false         reasoning=False content='Hello'
request_enable_false             reasoning=False content='Hello'
request_enable_true              reasoning=True  content=''
request_enable_true_budget64     reasoning=True  content='Hello'
```

Interpretation:

- Server default can be no-thinking via CLI `chat-template-kwargs`.
- Request-level `chat_template_kwargs.enable_thinking=true` overrides the default and re-enables thinking.
- `enable_thinking=true` alone may spend all output tokens in reasoning and return empty `content`.
- Adding `thinking_budget_tokens` caps the thinking and allows final content, but Pi may not currently send this field for Qwen chat-template mode.

## Pi configuration implication

Pi custom model config uses `api: "openai-completions"` for local llama.cpp/LM Studio-compatible servers. That is correct transport-wise.

The important Qwen distinction is `compat.thinkingFormat`:

- `"qwen"` sends top-level:

```json
{
  "enable_thinking": true
}
```

- `"qwen-chat-template"` sends:

```json
{
  "chat_template_kwargs": {
    "enable_thinking": true,
    "preserve_thinking": true
  }
}
```

For local `llama-server` with this Qwen GGUF, use:

```json
"compat": {
  "thinkingFormat": "qwen-chat-template"
}
```

Pi implementation evidence from installed bundle:

`/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai/dist/providers/openai-completions.js`

```js
else if (compat.thinkingFormat === "qwen-chat-template" && model.reasoning) {
    params.chat_template_kwargs = {
        enable_thinking: !!options?.reasoningEffort,
        preserve_thinking: true,
    };
}
```

## Recommended Pi model entry shape

For the local llama.cpp Qwen endpoint, configure the model as reasoning-capable so Pi can toggle thinking:

```json
{
  "id": "qwen36-35b-a3b-nothink",
  "name": "Qwen3.6 35B A3B Q4_K_M",
  "reasoning": true,
  "input": ["text"],
  "contextWindow": 262144,
  "maxTokens": 8192,
  "thinkingLevelMap": {
    "off": "none"
  },
  "compat": {
    "supportsDeveloperRole": false,
    "requiresAssistantAfterToolResult": true,
    "thinkingFormat": "qwen-chat-template"
  }
}
```

Caveat: Pi's `qwen-chat-template` mode sends `chat_template_kwargs.enable_thinking`, but no observed `thinking_budget_tokens`. For thinking-on use, consider increasing `maxTokens` or adding Pi support for `thinking_budget_tokens` if empty-content responses remain common.

## Current recommended launcher state

Keep `~/dev-external/start-mtp.sh` default-off but request-overridable:

```bash
  --reasoning auto \
  --chat-template-kwargs '{"enable_thinking":false}' \
```

Use hard-off only if Pi/client-side thinking control is not desired or not working:

```bash
  --reasoning off \
  --reasoning-budget 0 \
```
