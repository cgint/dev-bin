#!/usr/bin/env -S uv run --script
import sys
import json
import urllib.request
import urllib.error
import os

def get_model_info(model_name):
    url = "http://localhost:11434/api/show"
    data = json.dumps({"name": model_name}).encode('utf-8')
    req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
    
    try:
        with urllib.request.urlopen(req) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result
    except urllib.error.URLError as e:
        print(f"Error connecting to Ollama for {model_name}: {e}")
        return None

def extract_config(model_name):
    info = get_model_info(model_name)
    if not info:
        return None
        
    context_window = 8192 # default fallback
    
    # Try to extract from model_info
    if 'model_info' in info:
        for key, value in info['model_info'].items():
            if key.endswith('.context_length'):
                context_window = value
                break
                
    # Check parameters for num_predict (max tokens)
    max_tokens = 8192 # sensible default
    if 'parameters' in info and info['parameters']:
        for line in info['parameters'].split('\n'):
            parts = line.split()
            if len(parts) >= 2 and parts[0] == 'num_predict':
                try:
                    max_tokens = int(parts[1])
                except ValueError:
                    pass
                    
    if context_window < max_tokens:
        max_tokens = context_window

    reasoning = False
    if 'thinking' in info.get('capabilities', []) or 'thinking' in model_name.lower():
        reasoning = True

    model_config = {
        "id": model_name,
        "name": model_name,
        "reasoning": reasoning,
        "input": ["text"],
        "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
        "contextWindow": context_window,
        "maxTokens": max_tokens
    }
    
    return model_config

def update_models_json(new_models):
    json_path = "models.json"
    if not os.path.exists(json_path):
        print(f"{json_path} not found.")
        return
        
    with open(json_path, 'r') as f:
        data = json.load(f)
        
    if "providers" not in data or "ollama" not in data["providers"]:
        print("Invalid models.json structure.")
        return
        
    existing_models = data["providers"]["ollama"].setdefault("models", [])
    
    for new_model in new_models:
        # Replace if exists, else append
        replaced = False
        for i, m in enumerate(existing_models):
            if m["id"] == new_model["id"]:
                existing_models[i] = new_model
                replaced = True
                break
        if not replaced:
            existing_models.append(new_model)
            
    with open(json_path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Updated {json_path} with {len(new_models)} models.")

if __name__ == "__main__":
    models = []
    
    # Check for arguments first
    if len(sys.argv) > 1:
        for arg in sys.argv[1:]:
            if arg.endswith('.txt') and os.path.isfile(arg):
                print(f"Reading models from {arg}...")
                with open(arg, 'r') as f:
                    models.extend([line.strip() for line in f if line.strip()])
            else:
                models.append(arg)
                
    # If no arguments provided, check for a default models file
    elif os.path.isfile('ollama_models.txt'):
        print("Found ollama_models.txt, reading models from it...")
        with open('ollama_models.txt', 'r') as f:
            models.extend([line.strip() for line in f if line.strip()])
    elif os.path.isfile('models.txt'):
        print("Found models.txt, reading models from it...")
        with open('models.txt', 'r') as f:
            models.extend([line.strip() for line in f if line.strip()])
    else:
        print("Usage: python get_ollama_models.py <model1> <model2> ...")
        print("Alternatively, pass a text file: python get_ollama_models.py models.txt")
        print("Or simply place an 'ollama_models.txt' or 'models.txt' with one model per line in this directory.")
        sys.exit(1)
        
    # Remove duplicates
    models = list(dict.fromkeys(models))
    results = []
    
    for model in models:
        print(f"Fetching config for {model}...")
        config = extract_config(model)
        if config:
            results.append(config)
            
    if results:
        update_models_json(results)
    else:
        print("No models were successfully processed.")
