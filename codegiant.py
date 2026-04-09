#!/usr/bin/env python3

import os
import sys
import argparse
import json
import time
import datetime
import subprocess
import urllib.request
import urllib.error
import glob
import re
import shutil
import signal

# --- Configuration ---
LLM_API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta"
LLM_API_KEY = os.environ.get("GEMINI_API_KEY")

# Model definitions matching codegiant.sh
LLM_MODEL_DEFAULT = "gemini-3.1-pro-preview" # Default in python script
LLM_MODEL_FLASH = "gemini-3-flash-preview"
LLM_MODEL_FLASH_THINKING_BUDGET = -1

# Default configuration
LLM_CONFIG = {
    "temperature": 1,
    "maxOutputTokens": 65536
}

# --- Global Variables ---
TIMESTAMP = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
OUTPUT_DIR = ".codegiant"
SCRIPT_NAME = os.path.basename(__file__)

# --- Helper Functions ---

def print_err(*args, **kwargs):
    """Print to stderr."""
    print(*args, file=sys.stderr, **kwargs)
    sys.stderr.flush()

def handle_interrupt(sig, frame):
    """Handle Ctrl+C gracefully."""
    print_err("\n\n[Interrupted by user]")
    sys.exit(130)

# Register signal handler
signal.signal(signal.SIGINT, handle_interrupt)

def ensure_codegiant_dir(always_yes=False):
    """Ensure the output directory exists and is ignored by git."""
    gitignore_file = ".gitignore"
    
    if not os.path.isdir(OUTPUT_DIR):
        print_err()
        print_err(" ================================================")
        print_err(f" =  Directory '{OUTPUT_DIR}/' does not exist.")
        print_err(" ================================================")
        
        if always_yes:
            reply = "y"
            print_err(f" [--yes/-y flag set: Automatically creating '{OUTPUT_DIR}/' and adding to '{gitignore_file}']")
        else:
            try:
                reply = input(f" Should I create '{OUTPUT_DIR}/' and add it to '{gitignore_file}'? (y/n) ")
                print_err() # Move to new line
            except EOFError:
                reply = "n"

        if reply.lower().startswith('y'):
            print_err(f"Creating '{OUTPUT_DIR}/'...")
            try:
                os.makedirs(OUTPUT_DIR, exist_ok=True)
            except OSError:
                print_err(f"Error: Failed to create directory '{OUTPUT_DIR}/'. Exiting.")
                sys.exit(1)

            # Add to .gitignore if needed
            content = ""
            if os.path.isfile(gitignore_file):
                with open(gitignore_file, 'r') as f:
                    content = f.read()
            
            if f"{OUTPUT_DIR}/" not in content:
                print_err(f"Adding '{OUTPUT_DIR}/' to '{gitignore_file}'...")
                with open(gitignore_file, 'a') as f:
                    if content and not content.endswith('\n'):
                        f.write('\n')
                    f.write("# Ignore Code Giant output directory\n")
                    f.write(f"{OUTPUT_DIR}/\n")
            else:
                print_err(f"'{OUTPUT_DIR}/' already found in '{gitignore_file}'.")
        else:
            print_err(f"User declined creating '{OUTPUT_DIR}/'. Output cannot be written there. Exiting.")
            sys.exit(1)

def find_collector_script():
    """Find the codecollector script."""
    # Prefer local codecollector.py
    local_path = os.path.join(SCRIPT_DIR, "codecollector.py")
    if os.path.isfile(local_path):
        print_err(f"Using Python collector: {local_path}")
        return local_path
    
    # Check PATH
    path = shutil.which("codecollector.py")
    if path:
        print_err(f"Using Python collector from PATH: {path}")
        return path
    
    return ""

def expand_globs(items):
    """Replicates the shell glob expansion logic."""
    if not items:
        return []
    
    expanded = []
    for item in items:
        # Handle comma-separated lists
        parts = [p.strip() for p in item.split(',')]
        for part in parts:
            # Check for glob characters
            if any(char in part for char in ['*', '?', '[']):
                matches = glob.glob(part)
                if matches:
                    expanded.extend(matches)
                else:
                    # If no matches, keep original pattern (bash behavior warning)
                    print_err(f"  Warning: Pattern '{part}' didn't match any files")
                    expanded.append(part)
            else:
                expanded.append(part)
    return expanded

def generate_config_json(model, thinking_budget):
    """Generate the generationConfig JSON."""
    config = LLM_CONFIG.copy()
    
    # Remove thinking budget if -1 or not a 2.5 model
    # Logic from bash script: if model is 2.5 AND budget != -1
    is_2_5 = "gemini-2.5-" in model
    is_3 = "gemini-3-" in model
    
    final_config = {
        "temperature": config["temperature"],
        "maxOutputTokens": config["maxOutputTokens"]
    }
    
    if is_2_5 and thinking_budget != -1:
        final_config["thinkingConfig"] = {
            "thinkingBudget": thinking_budget
        }
    if is_3:
        final_config["temperature"] = 1
        
    return final_config

def process_grounding_info(raw_output_file, search_enabled):
    """Extract and format grounding information from raw JSON response."""
    if not search_enabled:
        return ""
    
    if not os.path.isfile(raw_output_file) or os.path.getsize(raw_output_file) == 0:
        return ""

    # Read raw file to find grounding metadata
    last_chunk_with_grounding = None
    
    try:
        with open(raw_output_file, 'r') as f:
            lines = f.readlines()
            
        # Iterate backwards to find the last relevant chunk
        for line in reversed(lines):
            clean_line = line.strip()
            if clean_line.startswith("data: "):
                clean_line = clean_line[6:]
            
            if "groundingMetadata" in clean_line:
                try:
                    data = json.loads(clean_line)
                    candidates = data.get("candidates", [])
                    if candidates and "groundingMetadata" in candidates[0]:
                        last_chunk_with_grounding = candidates[0]["groundingMetadata"]
                        break
                except json.JSONDecodeError:
                    continue
    except Exception as e:
        print_err(f"Error reading raw output for grounding: {e}")
        return ""

    if not last_chunk_with_grounding:
        if search_enabled:
            print_err("  LLM did not use Grounding Tool although requested with -S")
            return "\n\n## Grounding Information\n\n**Note:** LLM was instructed to use Google Search via -S flag but did not use it for this query.\n\n"
        return ""

    print_err("  Processing grounding information...")
    
    md = "\n\n## Grounding Information\n\n"
    
    # --- Search Entry Point ---
    sep = last_chunk_with_grounding.get("searchEntryPoint", {})
    if sep:
        md += "### Search Entry Point\n\n"
        md += "The response includes a search entry point containing Google Search Suggestions. These are the search queries that were used to ground the response.\n\n"
        
        rendered_content = sep.get("renderedContent", "")
        search_queries = []
        
        # Method 1: Regex for chips
        chip_matches = re.findall(r'class="chip"[^>]*>([^<]*)</a>', rendered_content)
        for match in chip_matches:
            query = match.replace('&lt;', '<').replace('&gt;', '>').replace('&amp;', '&').replace('&quot;', '"')
            if query:
                search_queries.append(query)
        
        # Method 2: webSearchQueries fallback
        if not search_queries:
            wsq = last_chunk_with_grounding.get("webSearchQueries", [])
            search_queries.extend(wsq)

        if search_queries:
            md += "**Search Queries:**\n"
            for q in search_queries:
                md += f"* {q}\n"
            md += "\n"
        else:
            md += "No specific search queries found in the entry point data.\n\n"

    # --- Grounding Supports ---
    supports = last_chunk_with_grounding.get("groundingSupports", [])
    if supports:
        md += "### Supported Segments\n\n"
        segment_found = False
        for support in supports:
            segment = support.get("segment", {})
            text = segment.get("text", "")
            if text:
                indices = support.get("groundingChunkIndices", [])
                md += f"*   **Segment:** `{text}`\n"
                md += f"    *   Supported by Source Indices: {indices}\n\n"
                segment_found = True
        
        if not segment_found:
            md += "*   No segments with text found\n\n"
    else:
        print_err("  No groundingSupports found in the response.")

    # --- Sources (Chunks) ---
    chunks = last_chunk_with_grounding.get("groundingChunks", [])
    if chunks:
        md += "### Sources\n\n"
        for idx, chunk in enumerate(chunks):
            web = chunk.get("web", {})
            title = web.get("title")
            uri = web.get("uri")
            if title and uri:
                md += f"* **Source {idx}**: {title}\n"
                md += f"  * Redirect URI: {uri}\n\n"
    else:
        print_err("  No groundingChunks found in the response.")

    # --- Web Search Queries (if not already shown) ---
    wsq = last_chunk_with_grounding.get("webSearchQueries", [])
    if wsq and not sep:
        md += "### Web Search Queries\n\n"
        for q in wsq:
            md += f"* {q}\n"
        md += "\n"
    elif not sep and not wsq:
         md += "### Web Search Queries\n\n* No specific search queries found\n\n"

    # --- Explanation ---
    md += "### Understanding and Resolving Redirect URLs\n\n"
    md += "The URIs in the grounding metadata contain a redirect mechanism through the Vertex AI Search domain. These links provide attribution to the source content providers and track usage for billing purposes.\n\n"
    md += "**How the redirection works:**\n"
    md += "1. The model returns a URL like: `https://vertexaisearch.cloud.google.com/grounding-api-redirect/AWhgh4...`\n"
    md += "2. When accessed, this URL redirects to the actual source website (e.g., wikipedia.org, cnn.com)\n"
    md += "3. The script attempts to automatically resolve these redirects to show you the actual destination\n\n"
    md += "**If automatic resolution failed, you can manually resolve the redirect URLs using:**\n\n"
    md += "```bash\ncurl -IL <redirect_url>\n```\n\n"
    md += "**Example:**\n```bash\n$ curl -IL https://vertexaisearch.cloud.google.com/grounding-api-redirect/ABCXYZ123...\nHTTP/2 302\nlocation: https://www.example.com/article/12345\n...\n```\n\n"
    md += "Look for the 'Location:' header in the response to find the actual destination URL.\n"
    md += "The provided redirect URIs remain accessible for 30 days after the grounded result is generated. After this period, they will no longer work.\n\n"
    md += "**Important:** These URIs are intended for direct human access only. Automated access to these URLs outside this script may violate Google's terms of service.\n\n"

    return md

def main():
    global TIMESTAMP
    
    # --- Argument Parsing ---
    parser = argparse.ArgumentParser(description="Orchestrates context collection and LLM interaction.", add_help=False)
    
    # Core Options
    parser.add_argument('-f', metavar='request_file', help="Path to a file containing the user's request")
    parser.add_argument('-t', metavar='request_text', help="The user's request as a string")
    parser.add_argument('-c', metavar='context_file', help="Path to an existing context file")
    parser.add_argument('-o', metavar='output_file', help="Copy the formatted response to an additional file location")
    parser.add_argument('-r', metavar='prev_context', help="Path to previous context file for followup questions")
    parser.add_argument('-F', '--flash25', action='store_true', help="Use the flash 2.5 model")
    parser.add_argument('-P25', '--pro25', action='store_true', help="Use the pro 2.5 model")
    parser.add_argument('-D', '--dry-run', action='store_true', help="Generate context file only, do not call LLM")
    parser.add_argument('-S', '--search', action='store_true', help="Enable Google Search tool")
    parser.add_argument('-y', '--yes', action='store_true', help="Skip prompt for .codegiant directory creation")
    parser.add_argument('-h', '--help', action='help', help="Display this help message")

    # Collection Options
    parser.add_argument('-e', metavar='extensions', help="Comma-separated list of file extensions")
    parser.add_argument('-l', metavar='file_list', help="Path to file containing list of files")
    parser.add_argument('-d', action='append', metavar='directories', help="Directories to include")
    parser.add_argument('-a', action='append', metavar='files', help="Individual files to always add")
    parser.add_argument('-i', action='append', metavar='files', help="Individual files to include exclusively")
    parser.add_argument('-x', action='append', metavar='exclude_dirs', help="Directories to exclude")
    parser.add_argument('-X', action='append', metavar='exclude_files', help="Files to exclude")
    parser.add_argument('-O', action='append', metavar='omit_files', help="Files to omit content but include in tree")
    parser.add_argument('-I', action='store_true', help="Ignore .codegiantignore file")

    args = parser.parse_args()

    # --- Global State Setup ---
    
    # Check API Key
    if not LLM_API_KEY:
        print_err("Error: GEMINI_API_KEY environment variable is not set.")
        print_err("Please set it with: export GEMINI_API_KEY=your_key_here")
        sys.exit(1)

    # Model Selection
    if args.pro25 and args.flash25:
        print_err("Error: Cannot use more than one of -F (flash-2.5) or -P25 (pro-2.5) options together.")
        sys.exit(1)
    
    llm_model = LLM_MODEL_DEFAULT
    if args.flash25:
        llm_model = LLM_MODEL_FLASH
        print_err(f"[INFO] Using flash model: {llm_model}")

    # Request Validation
    user_request = ""
    
    if args.f:
        if args.t:
            print_err("Error: Cannot use both -f and -t options.")
            sys.exit(1)
        if not os.path.isfile(args.f):
            print_err(f"Error: Request file not found: {args.f}")
            sys.exit(1)
        with open(args.f, 'r') as f:
            user_request = f.read()
    elif args.t:
        user_request = args.t
    
    if not args.dry_run and not user_request:
        print_err("Error: Either -f or -t option must be provided unless using --dry-run (-D).")
        sys.exit(1)

    # Directory Setup
    ensure_codegiant_dir(args.yes)

    # --- Context Handling ---
    context_file = args.c
    previous_context_file = args.r
    followup_mode = False

    # Handle -r (Followup)
    if previous_context_file:
        # Resolve path
        if not os.path.exists(previous_context_file):
             if os.path.exists(os.path.join(OUTPUT_DIR, previous_context_file)):
                 previous_context_file = os.path.join(OUTPUT_DIR, previous_context_file)
        
        if not os.path.isfile(previous_context_file):
            print_err(f"Error: Previous context file not found: {previous_context_file}")
            sys.exit(1)
            
        # Extract timestamp
        filename = os.path.basename(previous_context_file)
        match = re.search(r'^(\d{8}_\d{6})', filename)
        if not match:
            print_err("Error: Invalid context filename format. Expected format: YYYYMMDD_HHMMSS_codegiant_context.md")
            sys.exit(1)
        
        TIMESTAMP = match.group(1)
        context_file = previous_context_file
        print_err(f"Using previous context file: {context_file}")

    # Handle -c (Provided Context)
    if context_file and not previous_context_file:
        if not os.path.exists(context_file):
             if os.path.exists(os.path.join(OUTPUT_DIR, context_file)):
                 context_file = os.path.join(OUTPUT_DIR, context_file)
        
        if not os.path.isfile(context_file):
            print_err(f"Error: Context file not found: {context_file}")
            sys.exit(1)
        
        print_err(f"Using provided context file: {context_file}")
        # Try to extract timestamp, else keep current
        match = re.search(r'(\d{8}_\d{6})', os.path.basename(context_file))
        if match:
            TIMESTAMP = match.group(1)

    # Generate Context if needed
    if not context_file:
        collector_script = find_collector_script()
        if not collector_script:
            print_err("Error: codecollector.py not found.")
            sys.exit(1)
            
        print_err()
        print_err(f"Step 1: Generating context file using {os.path.basename(collector_script)}...")
        
        context_filename = os.path.join(OUTPUT_DIR, f"{TIMESTAMP}_codegiant_context.md")
        
        # Build collector args
        collector_cmd = ["python3", collector_script] if collector_script.endswith('.py') else [collector_script]
        
        if args.e: collector_cmd.extend(["-e", args.e])
        if args.l: collector_cmd.extend(["-l", args.l])
        if args.I: collector_cmd.append("-I")
        if args.yes: collector_cmd.append("-y")
        
        # Handle lists and globs
        if args.d:
            for dir_path in expand_globs(args.d):
                collector_cmd.extend(["-d", dir_path])
        if args.x:
            for exclude_dir in expand_globs(args.x):
                collector_cmd.extend(["-x", exclude_dir])
        if args.X:
            for exclude_file in expand_globs(args.X):
                collector_cmd.extend(["-X", exclude_file])
        if args.O:
            for omit_file in expand_globs(args.O):
                collector_cmd.extend(["-O", omit_file])
        
        # Handle -i (Exclusive) vs others
        if args.i:
            if any([args.a, args.d, args.e, args.l]):
                print_err("Error: Option -i cannot be mixed with -a, -d, -e, or -l options.")
                sys.exit(1)
            expanded_i = expand_globs(args.i)
            collector_cmd.extend(["-i", ",".join(expanded_i)])
            print_err(f"  Exclusively including files (expanded): {expanded_i}")
        
        if args.a:
            expanded_a = expand_globs(args.a)
            for add_file in expanded_a:
                collector_cmd.extend(["-a", add_file])
            print_err(f"  Force-including files (expanded): {expanded_a}")

        collector_cmd.extend(["-o", context_filename])
        
        print_err(f"Executing: {' '.join(collector_cmd)}")
        
        try:
            subprocess.run(collector_cmd, check=True)
        except subprocess.CalledProcessError:
            print_err(f"Error: {os.path.basename(collector_script)} failed to generate context.")
            sys.exit(1)
            
        if not os.path.isfile(context_filename):
            time.sleep(1)
            if not os.path.isfile(context_filename):
                print_err(f"Error: The context file '{context_filename}' was not generated.")
                sys.exit(1)
        
        context_file = context_filename
        print_err(f"Context file generated: {context_file}")

    # Define Output Files
    raw_output_file = os.path.join(OUTPUT_DIR, f"{TIMESTAMP}_codegiant_llm_raw_output.json")
    markdown_output_file = os.path.join(OUTPUT_DIR, f"{TIMESTAMP}_codegiant_llm_response.md")

    # Check Followup Mode
    if os.path.isfile(markdown_output_file) and context_file == previous_context_file:
        followup_mode = True
        print_err(f"Followup mode: Will append to existing response file: {markdown_output_file}")

    # Dry Run Exit
    if args.dry_run:
        print_err("")
        print_err("--------------------------------------------------")
        print_err(" Dry Run Complete!")
        print_err("--------------------------------------------------")
        print_err(f"  Context File Generated: {context_file}")
        print_err("  Skipping LLM API call as requested.")
        print_err("--------------------------------------------------")
        sys.exit(0)

    # --- LLM API Call ---
    print_err("Step 3: Calling LLM API...")
    
    # Read Context
    try:
        with open(context_file, 'r') as f:
            context_content = f.read()
    except IOError as e:
        print_err(f"Error reading context file: {e}")
        sys.exit(1)

    # Construct Prompt
    prompt_parts = []
    
    if followup_mode:
        print_err("  Creating payload with followup context...")
        try:
            with open(markdown_output_file, 'r') as f:
                previous_response_content = f.read()
        except IOError:
            print_err("Error reading previous response file.")
            sys.exit(1)
            
        prompt_parts.append("You are a helpful coding assistant. I previously asked you a question and received a response. I now have a followup question.\n")
        prompt_parts.append("Original Project Context:\n\n```")
        prompt_parts.append(context_content)
        prompt_parts.append("```\n\nPrevious Request and Response:\n\n```")
        prompt_parts.append(previous_response_content)
        prompt_parts.append("```\n\nFollowup Request:\n\n```")
        prompt_parts.append(user_request)
        prompt_parts.append("```")
        
        # Append request to markdown file
        with open(markdown_output_file, 'a') as f:
            f.write(f"\n\n# Followup Request ({TIMESTAMP})\n\n```\n{user_request}\n```\n\n# Followup Response\n\n")
            
    else:
        print_err("  Creating payload for initial request...")
        prompt_parts.append("You are a helpful coding assistant. Analyze the provided project context (directory structure and file contents) and follow the user's request.\n")
        prompt_parts.append("Project Context:\n\n```")
        prompt_parts.append(context_content)
        prompt_parts.append("```\n\nUser Request:\n\n```")
        prompt_parts.append(user_request)
        prompt_parts.append("```")
        
        # Initialize markdown file
        with open(markdown_output_file, 'w') as f:
            f.write(f"# Request ({TIMESTAMP})\n\n```\n{user_request}\n```\n\n# Response\n\n")

    full_prompt = "".join(prompt_parts)

    # Build JSON Payload
    payload = {
        "contents": [{"role": "user", "parts": [{"text": full_prompt}]}],
        "generationConfig": generate_config_json(llm_model, LLM_MODEL_FLASH_THINKING_BUDGET)
    }
    
    if args.search:
        print_err("  Adding search capability to payload")
        payload["tools"] = [{"googleSearch": {}}]

    json_data = json.dumps(payload).encode('utf-8')
    
    print_err(f"  Payload size: {len(json_data)} bytes")
    
    # API Request
    api_endpoint = f"{LLM_API_BASE_URL}/models/{llm_model}:streamGenerateContent?alt=sse"
    print_err(f"  Sending streaming request to {api_endpoint}...")
    print_err(f"  Sending streaming request with config: {json.dumps(payload['generationConfig'], indent=2)}")
    print_err()

    headers = {
        "Content-Type": "application/json",
        "x-goog-api-key": LLM_API_KEY
    }

    req = urllib.request.Request(api_endpoint, data=json_data, headers=headers, method="POST")

    # Streaming Response Handling
    last_chunk_json = None
    
    try:
        with open(raw_output_file, 'w') as raw_f, open(markdown_output_file, 'a') as md_f:
            with urllib.request.urlopen(req) as response:
                for line in response:
                    line_str = line.decode('utf-8')
                    
                    # Save raw output
                    raw_f.write(line_str)
                    raw_f.flush()
                    
                    line_str = line_str.strip()
                    if line_str.startswith("data: "):
                        json_str = line_str[6:]
                        try:
                            data = json.loads(json_str)
                            last_chunk_json = data
                            
                            # Extract text content
                            candidates = data.get("candidates", [])
                            if candidates:
                                parts = candidates[0].get("content", {}).get("parts", [])
                                if parts:
                                    text = parts[0].get("text", "")
                                    if text:
                                        sys.stdout.write(text)
                                        sys.stdout.flush()
                                        md_f.write(text)
                                        md_f.flush()
                        except json.JSONDecodeError:
                            pass
    except urllib.error.HTTPError as e:
        print_err(f"Error: HTTP request failed with code {e.code}")
        print_err(e.read().decode('utf-8'))
        sys.exit(1)
    except Exception as e:
        print_err(f"Error during API call: {e}")
        sys.exit(1)

    print_err("\n\n---------------------------------")
    print_err("- Finished processing stream.")
    print_err()
    print_err(f"Step 4: LLM response has been streamed to: {markdown_output_file}")

    # --- Post Processing ---
    
    # Token Usage
    total_prompt_tokens = 0
    total_candidates_tokens = 0
    total_thoughts_tokens = 0
    total_total_tokens = 0

    if last_chunk_json:
        usage = last_chunk_json.get("usageMetadata", {})
        total_prompt_tokens = usage.get("promptTokenCount", 0)
        total_candidates_tokens = usage.get("candidatesTokenCount", 0)
        total_thoughts_tokens = usage.get("thoughtsTokenCount", 0)
        total_total_tokens = usage.get("totalTokenCount", 0)
        
        # Fallback for candidates
        if total_candidates_tokens == 0:
            candidates = last_chunk_json.get("candidates", [])
            if candidates and "tokenCount" in candidates[0]:
                total_candidates_tokens = candidates[0]["tokenCount"]

    # Grounding Info
    grounding_md = process_grounding_info(raw_output_file, args.search)
    
    with open(markdown_output_file, 'a') as f:
        if grounding_md:
            print_err("")
            print_err("--------------------------------------------------")
            print_err("🔎 Grounding Information Extracted")
            print_err("--------------------------------------------------")
            print(grounding_md) # Print to stdout
            print_err("--------------------------------------------------")
            f.write(grounding_md)
        elif args.search:
            print_err("  ❌ (No grounding information found in the response)")
            f.write("\n\n❌ **(No grounding information found in the response)**\n\n")

        # Final Stats
        print_err("")
        print_err("--------------------------------------------------")
        print_err("✨ Code Giant processing complete! ✨")
        print_err("--------------------------------------------------")
        print_err(f"📊 Token Usage '{llm_model}'")
        print_err(f"  ├─ Prompt:    {total_prompt_tokens}")
        print_err(f"  ├─ Response:  {total_candidates_tokens}")
        print_err(f"  ├─ Thoughts:  {total_thoughts_tokens}")
        print_err(f"  └─ Total:     {total_total_tokens}")
        print_err("--------------------------------------------------")
        print_err("📁 Output Files")
        print_err(f"  ├─ Context:   {context_file}")
        print_err(f"  ├─ Raw:       {raw_output_file}")
        print_err(f"  └─ Response:  {markdown_output_file}")
        
        token_usage = "\n\n## Token Usage\n\n"
        token_usage += f"🔢 **Model**: {llm_model}\n\n"
        token_usage += "📊 Token Usage\n"
        token_usage += f"  ├─ Prompt:    {total_prompt_tokens}\n"
        token_usage += f"  ├─ Response:  {total_candidates_tokens}\n"
        token_usage += f"  ├─ Thoughts:  {total_thoughts_tokens}\n"
        token_usage += f"  └─ Total:     {total_total_tokens}\n\n"
        token_usage += "## Generated Files\n\n"
        token_usage += f"* Context: {context_file}\n"
        token_usage += f"* Raw Output: {raw_output_file}\n"
        token_usage += f"* Response: {markdown_output_file}\n"
        f.write(token_usage)

    # Additional Output Copy
    if args.o:
        additional_file = args.o
        # Expand user home
        additional_file = os.path.expanduser(additional_file)
        
        parent_dir = os.path.dirname(additional_file)
        if parent_dir and not os.path.exists(parent_dir):
            print_err(f"Directory '{parent_dir}' does not exist. Creating it.")
            try:
                os.makedirs(parent_dir, exist_ok=True)
            except OSError:
                print_err(f"Error: Failed to create directory '{parent_dir}'.")
                sys.exit(1)
        
        # Check write permission
        if parent_dir and not os.access(parent_dir, os.W_OK):
             print_err(f"Error: No write permission for directory: {parent_dir}")
             sys.exit(1)
             
        md_abs = os.path.abspath(markdown_output_file)
        add_abs = os.path.abspath(additional_file)
        
        if md_abs != add_abs:
            print_err(f"📋 Copying formatted response to: {additional_file}")
            try:
                shutil.copy2(markdown_output_file, additional_file)
                print_err(f"  ✅ Successfully copied to: {additional_file}")
                print_err(f"  └─ Copy:      {additional_file}")
                print_err("--------------------------------------------------")
            except Exception as e:
                print_err(f"  ❌ Failed to copy to: {additional_file}")
                print_err("  Please check file permissions and try again.")

if __name__ == "__main__":
    main()