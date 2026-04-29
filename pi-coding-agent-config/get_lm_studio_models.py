#!/usr/bin/env -S uv run --script
"""Auto-discover models from LM Studio instances and update models.json.

LM Studio exposes an OpenAI-compatible /v1/models endpoint that returns
only {id, object, owned_by} — no context window or metadata. This script:

  1. Calls /v1/models on each configured LM Studio endpoint
  2. Infers metadata (contextWindow, maxTokens, reasoning) from model names
  3. Updates ./models.json for reachable providers only

If an endpoint is unreachable, its existing entries are left untouched.
"""

import json
import os
import re
import sys
import urllib.error
import urllib.request


# Default LM Studio endpoints to discover
DEFAULT_ENDPOINTS = {
    "lms-local": "http://127.0.0.1:1234/v1",
    "lms-twins": "http://twins:1234/v1",
    "lms-sparky": "http://sparky:1234/v1",
    # "lm-studio-scaleway": "http://127.0.0.1:1111/v1",
}


def infer_metadata(model_id):
    """Infer model metadata from the model ID using naming heuristics.

    LM Studio's /v1/models returns only {id, object, owned_by}, so we
    infer contextWindow and reasoning capability from the model name.

    Args:
        model_id: The model identifier string (e.g., "qwen3.6-35b-a3b")

    Returns:
        dict with contextWindow, maxTokens, reasoning fields
    """
    model_lower = model_id.lower()

    # --- Embedding models: signal to skip ---
    if any(prefix in model_lower for prefix in [
        "text-embedding", "nomic-embed", "embed-",
    ]):
        return {"__embedding__": True}

    # Context window heuristics based on known model families
    context_window = 32768  # sensible default for unknown models

    if any(prefix in model_lower for prefix in [
        "qwen3", "qwen2.5", "gemma4", "glm-4"
    ]):
        context_window = 262144
    elif "glm-ocr" in model_lower:
        context_window = 32768

    # Max tokens — reasonable default for local models
    max_tokens = 8192

    # Reasoning detection: "thinking" in name, or known reasoning model families
    reasoning = False
    if any(marker in model_lower for marker in [
        "thinking", "reason"
    ]):
        reasoning = True
    # Qwen3.x, Qwen3.5/3.6, Gemma4 (hyphenated or not), glm-4.7, gpt-oss are reasoning-capable
    elif any(prefix in model_lower for prefix in [
        "qwen3", "gemma4", "gemma-4", "glm-4.7", "gpt-oss"
    ]):
        reasoning = True

    return {
        "contextWindow": context_window,
        "maxTokens": max_tokens,
        "reasoning": reasoning,
    }


def discover_models(base_url):
    """Discover all models from an LM Studio instance.

    Args:
        base_url: The LM Studio API base URL (e.g., http://127.0.0.1:1234/v1)

    Returns:
        list of model ID strings, or empty list if unreachable
    """
    models_url = f"{base_url.rstrip('/')}/models"

    try:
        req = urllib.request.Request(models_url)
        with urllib.request.urlopen(req, timeout=5) as response:
            data = json.loads(response.read().decode('utf-8'))

        model_ids = []
        for entry in data.get("data", []):
            mid = entry.get("id")
            if mid:
                model_ids.append(mid)

        return model_ids

    except (urllib.error.URLError, OSError, json.JSONDecodeError) as e:
        print(f"  [SKIP] {base_url} — not reachable ({type(e).__name__})")
        return []


def build_model_entry(model_id):
    """Build a full model config object from an ID.

    Args:
        model_id: The model identifier string

    Returns:
        dict with all fields matching the models.json schema, or None for embedding models
    """
    meta = infer_metadata(model_id)
    if meta.get("__embedding__"):
        return None

    # Detect multimodal models from the model ID suffix.
    # LM Studio's /v1/models exposes no modality metadata, so we
    # rely on known patterns in the last segment of the ID.
    suffix = model_id.rsplit("/", 1)[-1].lower()

    multimodal_prefixes = ["gemma-4", "phi-4"]
    is_multimodal = any(p in suffix for p in multimodal_prefixes)

    # Qwen3.5/3.6: models with >= 4B params are multimodal (vision-capable).
    # Tiny variants (0.8B, 4B) are text-only.
    # Extract the main parameter count from names like "qwen3.6-35b-a3b" or "qwen3.5-9b".
    if not is_multimodal:
        m = re.search(r"qwen3\.(?:5|6)[-_](\d+\.?\d*)b", suffix)
        if m:
            params_b = float(m.group(1))
            is_multimodal = params_b >= 9  # 9B+ Qwen3.5/3.6 are multimodal

    input_types = ["text", "image"] if is_multimodal else ["text"]

    return {
        "id": model_id,
        "name": model_id,
        "reasoning": meta["reasoning"],
        "input": input_types,
        "cost": {
            "input": 0,
            "output": 0,
            "cacheRead": 0,
            "cacheWrite": 0,
        },
        "contextWindow": meta["contextWindow"],
        "maxTokens": meta["maxTokens"],
    }


def update_models_json(provider_key, base_url, models):
    """Update models.json with discovered models for a given provider.

    Updates entries for this provider; does not touch other providers.

    Behavior:
      - reachable providers: write/replace the "models" list
      - preserve existing provider fields (e.g. apiKey, compat) if present
      - set baseUrl to the scanned base_url (fixes custom --provider usage)

    Args:
        provider_key: The provider key in models.json (e.g., "lms-local")
        base_url: The base URL scanned for this provider (e.g., http://127.0.0.1:1234/v1)
        models: List of model config dicts to write
    """
    # Strictly update ./models.json (CWD). No searching, no CLI param.
    json_path = "models.json"

    if not os.path.exists(json_path):
        abs_path = os.path.abspath(json_path)
        print(f"[WARN] {json_path} not found at {abs_path} — skipping update.")
        print("       Run this script from the directory containing models.json.")
        return

    with open(json_path, 'r') as f:
        data = json.load(f)

    if "providers" not in data or not isinstance(data["providers"], dict):
        print("[WARN] No 'providers' key in models.json — skipping update.")
        return

    existing = data["providers"].get(provider_key)
    if isinstance(existing, dict):
        provider_obj = dict(existing)  # shallow copy
    else:
        provider_obj = {}

    # Ensure required fields for pi's schema when custom models are defined
    provider_obj["baseUrl"] = base_url
    provider_obj["api"] = "openai-completions"
    if "apiKey" not in provider_obj:
        provider_obj["apiKey"] = "none"

    # Replace models list with discovered models
    provider_obj["models"] = models

    data["providers"][provider_key] = provider_obj

    with open(json_path, 'w') as f:
        json.dump(data, f, indent=2)

    print(f"  [OK] Updated '{provider_key}' with {len(models)} models.")


def main():
    """Main entry point: discover from all configured LM Studio endpoints."""

    # Determine which endpoints to scan
    if len(sys.argv) > 1:
        # Custom URL(s) provided via CLI — use them with an optional provider name
        endpoints = {}
        i = 1
        while i < len(sys.argv):
            arg = sys.argv[i]
            if arg.startswith("http"):
                provider_key = "lm-studio"  # default name
                if i + 1 < len(sys.argv) and sys.argv[i + 1].startswith("--provider"):
                    next_arg = sys.argv[i + 1]
                    if "=" in next_arg:
                        provider_key = next_arg.split("=", 1)[1]
                    else:
                        # --provider is at i+1, its value is at i+2
                        if i + 2 < len(sys.argv):
                            provider_key = sys.argv[i + 2]
                        else:
                            print("[ERROR] --provider requires a value")
                            sys.exit(1)
                    i += 2  # skip past --provider and its value
                endpoints[provider_key] = arg.rstrip("/")
            i += 1

        if not endpoints:
            print("Usage:")
            print("  python get_lm_studio_models.py")
            print("  python get_lm_studio_models.py http://host:1234/v1")
            print("  python get_lm_studio_models.py http://host:1234/v1 --provider my-lm-studio")
            sys.exit(1)

    else:
        # Use all default endpoints
        endpoints = dict(DEFAULT_ENDPOINTS)

    print(f"LM Studio Model Discovery")
    print(f"{'=' * 40}")

    total_discovered = 0

    for provider_key, base_url in endpoints.items():
        print(f"\nScanning {provider_key} ({base_url})...")

        model_ids = discover_models(base_url)

        if not model_ids:
            print(f"  No models found or endpoint unreachable — skipping.")
            continue

        # Build full model entries with inferred metadata
        models = []
        for mid in model_ids:
            entry = build_model_entry(mid)
            if entry is None:
                print(f"  [SKIP] {mid} — embedding model")
                continue
            models.append(entry)

        # Deduplicate by id (preserve order of first occurrence)
        seen = set()
        unique_models = []
        for m in models:
            if m["id"] not in seen:
                seen.add(m["id"])
                unique_models.append(m)

        update_models_json(provider_key, base_url, unique_models)
        total_discovered += len(unique_models)

    print(f"\n{'=' * 40}")
    print(f"Done. Discovered {total_discovered} models across all reachable endpoints.")


if __name__ == "__main__":
    main()
