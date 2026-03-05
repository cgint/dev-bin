#!/bin/bash

# mptranscribe.sh: Takes an MP3 file and sends it to Gemini for detailed transcription
# using the File API for proper large file handling.

# --- Configuration ---
API_BASE_URL="https://generativelanguage.googleapis.com"
LLM_API_KEY="${GEMINI_API_KEY}"
CHUNK_SIZE=$((8 * 1024 * 1024)) # 8MB chunks for upload
MAX_FILE_SIZE=$((200 * 1024 * 1024)) # 200MB limit
GENERATION_CONFIG_JSON=""

# Mode literal: flash_no_think | pro_low | flash3_minimal
LLM_VARIANT_SELECTED="flash3_minimal"

# Cache configuration
CACHE_DIR="${HOME}/.cache/mptranscribe"
CACHE_FILE="${CACHE_DIR}/file_cache.json"
CACHE_MAX_AGE=$((24 * 60 * 60)) # 24 hours in seconds
# --- End Configuration ---

set -eo pipefail # Exit on error, treat unset variables as error, exit on pipe failures

# --- Global Variables ---
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCRIPT_NAME=$(basename "$0")
AUDIO_FILE="" # Path to the audio file
TRANSCRIPTION_REQUEST="
Please provide a detailed transcription of this audio file.
- Include timestamps if possible, and identify any speakers if there are multiple voices.
- Make sure to capture all spoken content accurately without interpreting the content.
- Identify the speakers by name and start each block of text with the name of the speaker.
- The output text must match the spoken language of each participant in the audio recording without translating it.
"
RAW_OUTPUT_FILE=""
MARKDOWN_OUTPUT_FILE=""
TEMP_DIR="/tmp/mptranscribe_${TIMESTAMP}"
USE_FLASH_MODEL=0 # Flag to indicate flash model usage

# Token tracking variables
TOTAL_PROMPT_TOKENS=0
TOTAL_CANDIDATES_TOKENS=0
TOTAL_THOUGHTS_TOKENS=0
TOTAL_TOTAL_TOKENS=0

# --- Cache Functions ---
init_cache() {
    mkdir -p "$CACHE_DIR"
    if [[ ! -f "$CACHE_FILE" ]]; then
        echo "{}" > "$CACHE_FILE"
    fi
}

get_cached_file_uri() {
    local file="$1"
    local file_hash
    file_hash=$(sha256sum "$file" | cut -d' ' -f1)
    local cached_data
    
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 1
    fi
    
    cached_data=$(jq -r --arg hash "$file_hash" --arg path "$file" '.[$path] // empty' "$CACHE_FILE")
    if [[ -z "$cached_data" ]]; then
        return 1
    fi
    
    local timestamp
    local uri
    timestamp=$(echo "$cached_data" | jq -r '.timestamp')
    uri=$(echo "$cached_data" | jq -r '.uri')
    
    # Check if cache is still valid (less than 24 hours old)
    local current_time
    current_time=$(date +%s)
    local cache_age=$((current_time - timestamp))
    
    if [[ $cache_age -gt $CACHE_MAX_AGE ]]; then
        # Cache is too old, remove it
        update_cache "$file" "" ""
        return 1
    fi
    
    echo "$uri"
    return 0
}

update_cache() {
    local file="$1"
    local uri="$2"
    local file_hash
    file_hash=$(sha256sum "$file" | cut -d' ' -f1)
    local timestamp
    timestamp=$(date +%s)
    
    if [[ -z "$uri" ]]; then
        # Remove the entry if URI is empty
        jq --arg path "$file" 'del(.[$path])' "$CACHE_FILE" > "${CACHE_FILE}.tmp"
    else
        # Update or add the entry
        jq --arg path "$file" \
           --arg hash "$file_hash" \
           --arg uri "$uri" \
           --arg timestamp "$timestamp" \
           '.[$path] = {"hash": $hash, "uri": $uri, "timestamp": $timestamp|tonumber}' \
           "$CACHE_FILE" > "${CACHE_FILE}.tmp"
    fi
    mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
}

# --- Functions ---

usage() {
  echo "Usage: $SCRIPT_NAME <audio_file> [custom_request]"
  echo ""
  echo "  Takes an audio file and sends it to Gemini for detailed transcription"
  echo "  using the File API for proper large file handling."
  echo ""
  echo "  Arguments:"
  echo "    <audio_file>      Path to the audio file to transcribe (required)."
  echo "    [custom_request]  Optional custom transcription request text to send to Gemini."
  echo "                      If not provided, a default request for detailed transcription is used."
  echo ""
  echo "  Options:"
  echo "    -h, --help          Display this help message."
  echo ""
  echo "  Configuration:"
  echo "    GEMINI_API_KEY environment variable must be set."
  echo ""
  echo "  Outputs:"
  echo "    - ${TIMESTAMP}_transcript.md:         Extracted transcript in Markdown format."
  echo "    - ${TIMESTAMP}_mptranscribe_raw_output.json: Raw JSON response from Gemini API."
  exit 1
}

build_generation_config() {
  case "$LLM_VARIANT_SELECTED" in
    flash_no_think)
      LLM_MODEL="gemini-2.5-flash"
      ;;
    pro_low)
      LLM_MODEL="gemini-2.5-pro"
      ;;
    flash3_minimal)
      LLM_MODEL="gemini-3-flash-preview"
      ;;
    *)
      echo "Error: Invalid LLM_VARIANT_SELECTED value: $LLM_VARIANT_SELECTED" >&2
      echo "Valid values: flash_no_think | pro_low | flash3_minimal" >&2
      exit 1
      ;;
  esac

  if [[ "$LLM_VARIANT_SELECTED" == "flash3_minimal" ]]; then
    GENERATION_CONFIG_JSON=$(cat <<'EOF'
{
  "temperature": 0.2,
  "topK": 40,
  "topP": 0.95,
  "maxOutputTokens": 65536,
  "thinkingConfig": {
    "thinkingLevel": "minimal"
  }
}
EOF
)
  elif [[ "$LLM_VARIANT_SELECTED" == "pro_low" ]]; then
    GENERATION_CONFIG_JSON=$(cat <<'EOF'
{
  "temperature": 0.2,
  "topK": 40,
  "topP": 0.95,
  "maxOutputTokens": 65536,
  "thinkingConfig": {
    "thinkingBudget": 128
  }
}
EOF
)
  else
    GENERATION_CONFIG_JSON=$(cat <<'EOF'
{
  "temperature": 0.2,
  "topK": 40,
  "topP": 0.95,
  "maxOutputTokens": 65536,
  "thinkingConfig": {
    "thinkingBudget": 0
  }
}
EOF
)
  fi
}

check_dependencies() {
  local missing=0
  for cmd in curl jq file; do
    if ! command -v "$cmd" &> /dev/null; then
      echo "Error: Required command '$cmd' not found." >&2
      missing=1
    fi
  done
  if [[ "$missing" -eq 1 ]]; then
    echo "Please install the missing dependencies and try again." >&2
    exit 1
  fi
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    usage
  fi

  # Robust long option preprocessing: build a new argument list
  NEW_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --flash)
        NEW_ARGS+=("-F")
        ;;
      --help)
        NEW_ARGS+=("-h")
        ;;
      --)
        shift
        while [[ $# -gt 0 ]]; do
          NEW_ARGS+=("$1")
          shift
        done
        break
        ;;
      *)
        NEW_ARGS+=("$1")
        ;;
    esac
    shift
  done
  set -- "${NEW_ARGS[@]}"

  # Process positional arguments first
  AUDIO_FILE=""
  local positional_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -*) # Option
        break
        ;;
      *) # Positional argument
        positional_args+=("$1")
        shift
        ;;
    esac
  done

  if [[ ${#positional_args[@]} -eq 0 ]]; then
    echo "Error: Audio file argument is required." >&2
    usage
  fi
  AUDIO_FILE="${positional_args[0]}"
  if [[ ${#positional_args[@]} -ge 2 ]]; then
    TRANSCRIPTION_REQUEST="${positional_args[1]}"
  fi

  # Now process options
  while getopts ":Fh" opt; do
    case ${opt} in
      F)
        USE_FLASH_MODEL=1
        ;;
      h )
        usage
        ;;
      \?)
        echo "Invalid option: -$OPTARG" >&2
        usage
        ;;
    esac
  done
  shift $((OPTIND -1))

  # Validate audio file
  if [[ ! -f "$AUDIO_FILE" ]]; then
    echo "Error: Audio file not found: $AUDIO_FILE" >&2
    exit 1
  fi

  # Get the base name of the input file without extension
  local input_base_name
  input_base_name=$(basename "${AUDIO_FILE%.*}")
  
  # Define output files with input file name prefix
  RAW_OUTPUT_FILE="${input_base_name}_${TIMESTAMP}_mptranscribe_raw_output.json"
  MARKDOWN_OUTPUT_FILE="${input_base_name}_${TIMESTAMP}_transcript.md"

  # Check file size
  local file_size=$(wc -c < "$AUDIO_FILE")
  if [[ $file_size -gt $MAX_FILE_SIZE ]]; then
    echo "Error: File size ($(($file_size/1000000)) MB) exceeds maximum allowed size ($(($MAX_FILE_SIZE/1000000)) MB)." >&2
    exit 1
  fi

  if [[ -z "$LLM_API_KEY" ]]; then
    echo "Error: GEMINI_API_KEY environment variable is not set." >&2
    exit 1
  fi

  # Create temp directory
  mkdir -p "$TEMP_DIR"
}

get_mime_type() {
  local file="$1"
  local mime_type
  
  # Use file command to get MIME type
  mime_type=$(file --mime-type -b "$file")
  
  # If not an audio type, try to determine from extension
  if [[ ! "$mime_type" =~ ^audio/ ]]; then
    local file_lower=$(echo "$file" | tr "[:upper:]" "[:lower:]")
    case "$file_lower" in
      *.mp3)  mime_type="audio/mpeg" ;;
      *.m4a)  mime_type="audio/mp4" ;;
      *.wav)  mime_type="audio/wav" ;;
      *.ogg)  mime_type="audio/ogg" ;;
      *.opus) mime_type="audio/opus" ;;
      *)      mime_type="application/octet-stream" ;;
    esac
  fi
  
  echo "$mime_type"
}


wait_for_file_active() {
  local file_uri="$1"
  local file_id="${file_uri##*/}"
  local max_wait_seconds=60
  local interval_seconds=2
  local waited=0

  echo -n "Waiting for file to become active..."
  while [[ $waited -lt $max_wait_seconds ]]; do
    local status_response=$(curl -s "${API_BASE_URL}/v1beta/files/${file_id}?key=${LLM_API_KEY}")
    local state=$(echo "$status_response" | jq -r ".state")
    if [[ "$state" == "ACTIVE" ]]; then
      echo " active."
      return 0
    elif [[ "$state" == "FAILED" ]]; then
      echo " failed."
      echo "Error: File processing failed." >&2
      return 1
    elif [[ "$state" == "null" || -z "$state" ]]; then
      echo " error."
      echo "Error: Could not retrieve file state. Response: $status_response" >&2
      return 1
    fi
    echo -n "."
    sleep "$interval_seconds"
    waited=$((waited + interval_seconds))
  done
  echo " timeout."
  echo "Error: Timed out waiting for file to become active." >&2
  return 1
}

upload_file() {
  local file="$1"
  local file_size=$(wc -c < "$file")
  local mime_type=$(get_mime_type "$file")
  local display_name=$(basename "$file")
  
  # Initialize cache if needed
  init_cache
  
  # Check if we have a valid cached URI
  local cached_uri
  if cached_uri=$(get_cached_file_uri "$file"); then
    echo "Found valid cached file URI, skipping upload..."
    echo "$cached_uri" > "$TEMP_DIR/file_uri.txt"
    if wait_for_file_active "$cached_uri"; then
      return 0
    fi
    echo "Cached file URI is not active. Re-uploading..." >&2
    update_cache "$file" "" ""
  else
    echo "Starting file upload to Gemini File API..."
    echo "File: $display_name ($(($file_size/1000000)) MB, $mime_type)"
    
    # Step 1: Start the resumable upload
    local start_upload_response
    start_upload_response=$(curl -s -X POST \
      "${API_BASE_URL}/upload/v1beta/files?key=${LLM_API_KEY}" \
      -H "Content-Type: application/json" \
      -H "X-Goog-Upload-Protocol: resumable" \
      -H "X-Goog-Upload-Command: start" \
      -H "X-Goog-Upload-Header-Content-Length: ${file_size}" \
      -H "X-Goog-Upload-Header-Content-Type: ${mime_type}" \
      -d "{\"file\": {\"display_name\": \"${display_name}\"}}" \
      -D "$TEMP_DIR/headers.txt")
    
    # Extract upload URL from response headers
    local upload_url
    upload_url=$(grep -i "X-Goog-Upload-URL:" "$TEMP_DIR/headers.txt" | cut -d' ' -f2- | tr -d '\r\n')
    
    if [[ -z "$upload_url" ]]; then
      echo "Error: Failed to get upload URL from Gemini API" >&2
      exit 1
    fi
    
    # Step 2: Upload the file in chunks
    local upload_offset=0
    local upload_result=""
    
    echo "Uploading file in $(($CHUNK_SIZE/1000000))MB chunks..."
    
    while [[ $upload_offset -lt $file_size ]]; do
      local remaining_bytes=$((file_size - upload_offset))
      local chunk_size=$CHUNK_SIZE
      local is_last_chunk=false
      local command="upload"
      
      if [[ $remaining_bytes -le $CHUNK_SIZE ]]; then
        chunk_size=$remaining_bytes
        is_last_chunk=true
        command="upload, finalize"
      fi
      
      echo -n "  Uploading chunk $(($upload_offset/1000000))MB - $((($upload_offset + $chunk_size)/1000000))MB... "
      echo "  [DEBUG] Sending chunk with command: $command, offset: $upload_offset, size: $chunk_size, remaining: $remaining_bytes" >&2
      
      # Use dd to extract the chunk and curl to upload it
      upload_result=$(dd if="$file" bs=1 skip=$upload_offset count=$chunk_size 2>/dev/null | \
        curl -s -X POST "$upload_url" \
          -H "X-Goog-Upload-Command: $command" \
          -H "X-Goog-Upload-Offset: $upload_offset" \
          --data-binary @- 2>/dev/null)
      
      
      if [[ "$is_last_chunk" == "true" ]]; then
        # Parse the final response to get the file URI
        local file_uri
        if ! file_uri=$(echo "$upload_result" | jq -r '.file.uri' 2>"$TEMP_DIR/jq_error.log"); then
          echo "Error: Failed to parse upload response with jq" >&2
          echo "Raw response: $upload_result" >&2
          if [[ -f "$TEMP_DIR/jq_error.log" ]]; then
            echo "jq error:" >&2
            cat "$TEMP_DIR/jq_error.log" >&2
          fi
          exit 1
        fi
        if [[ -z "$file_uri" || "$file_uri" == "null" ]]; then
          echo "Error: Failed to get file URI from upload response" >&2
          echo "Raw response: $upload_result" >&2
          exit 1
        fi
        echo "done"
        echo "Upload complete. File URI: $file_uri"
        echo "$file_uri" > "$TEMP_DIR/file_uri.txt"
        
        # Update the cache with the new URI
        update_cache "$file" "$file_uri"
      else
        if [[ -z "$upload_result" ]]; then
          echo "done"
        else
          echo "Error: Unexpected response during upload" >&2
          echo "Raw response: $upload_result" >&2
          exit 1
        fi
      fi
      
      upload_offset=$((upload_offset + chunk_size))
    done
  fi
  # Ensure the file is active before returning
  if ! wait_for_file_active "$(cat "$TEMP_DIR/file_uri.txt")"; then
    exit 1
  fi
}

# Function to process streaming response chunks
process_stream_chunk() {
    local chunk="$1"
    local content
    
    # Extract content from the chunk using jq, handling SSE format
    if [[ "$chunk" == data:* ]]; then
        content=$(echo "${chunk#data: }" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
        if [[ -n "$content" ]]; then
            # Print to stdout and append to file
            echo -n "$content"
            echo -n "$content" >> "$MARKDOWN_OUTPUT_FILE"
        fi
        
        # Check if this is the final chunk (contains finishReason)
        # We still need to print the summary message here when the final chunk arrives.
        if echo "${chunk#data: }" | jq -e '.finishReason' >/dev/null 2>&1; then
             # We'll extract the *actual* token counts later, but print a notification now.
            echo -e "\\n\\n--------------------------------------------------"
            echo "✨ Transcription Complete (Processing Final Stats...) ✨"
            echo "--------------------------------------------------"
        fi
    fi
}

transcribe_audio() {
    echo "Requesting transcription from Gemini..."
    local model_to_use="$LLM_MODEL"
    local api_endpoint="${API_BASE_URL}/v1beta/models/${model_to_use}:streamGenerateContent?alt=sse"
    local file_uri
    file_uri=$(cat "$TEMP_DIR/file_uri.txt")
    
    # Prepare the Markdown output file
    echo -e "# Transcript (${TIMESTAMP})\n\n## Original File\n\n\`\`\`\n${AUDIO_FILE}\n\`\`\`\n\n## Transcription\n\n" > "$MARKDOWN_OUTPUT_FILE"
    
    # Create the request payload
    local payload_file
    payload_file=$(mktemp)
    
    cat > "$payload_file" << EOF
{
  "contents": [
    {
      "role": "user",
      "parts": [
        {
          "text": "${TRANSCRIPTION_REQUEST}"
        },
        {
          "file_data": {
            "file_uri": "${file_uri}",
            "mime_type": "$(get_mime_type "$AUDIO_FILE")"
          }
        }
      ]
    }
  ],
  "generationConfig": $GENERATION_CONFIG_JSON
}
EOF

    local payload_filesize=$(du -h "$payload_file" | cut -f1)
    echo "  [DEBUG] Payload file created, size: $payload_filesize" >&2

    echo "  Sending streaming request to $api_endpoint..." >&2
    
    # Clear the raw output file
    : > "$RAW_OUTPUT_FILE"

    # Make the streaming API call using curl and process each chunk
    curl -s -N --no-buffer -X POST "$api_endpoint" \
        -H "Content-Type: application/json" \
        -H "x-goog-api-key: $LLM_API_KEY" \
        -d @"$payload_file" | while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Save raw chunk for debugging
            echo "$line" >> "$RAW_OUTPUT_FILE"
            # Process and display the chunk
            process_stream_chunk "$line"
        fi
    done

    # Check curl exit status (using pipe status)
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "Error: curl command failed to execute." >&2
        rm -f "$payload_file"
        exit 1
    fi

    rm -f "$payload_file"
    echo -e "\n" # Add newline after streaming completes
}

cleanup() {
    echo "Cleaning up temporary files..."
    # Don't remove cache directory or cache file
    if [[ "$TEMP_DIR" != "$CACHE_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# --- Main Script ---

main() {
  check_dependencies
  parse_args "$@"
  build_generation_config

  upload_file "$AUDIO_FILE"
  transcribe_audio
  cleanup

  # Check the finish reason and extract final token counts from the raw output
  local finish_reason="UNKNOWN"
  TOTAL_PROMPT_TOKENS=0
  TOTAL_CANDIDATES_TOKENS=0
  TOTAL_THOUGHTS_TOKENS=0
  TOTAL_TOTAL_TOKENS=0

  if [[ -f "$RAW_OUTPUT_FILE" && -s "$RAW_OUTPUT_FILE" ]]; then
    # Find the last non-empty line in the file
    local last_non_empty_line
    last_non_empty_line=$(grep -v '^[[:space:]]*$' "$RAW_OUTPUT_FILE" | tail -n 1)
    local last_chunk_json=""

    if [[ "$last_non_empty_line" == data:* ]]; then
      last_chunk_json="${last_non_empty_line#data: }"
    else
      # Try parsing directly if not in SSE format (less likely but for robustness)
      last_chunk_json="$last_non_empty_line"
    fi

    # Use jq to extract finishReason and token counts safely
    if [[ -n "$last_chunk_json" ]]; then
      # Correct path for finishReason
      finish_reason=$(echo "$last_chunk_json" | jq -r '.candidates[0].finishReason // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")
      TOTAL_PROMPT_TOKENS=$(echo "$last_chunk_json" | jq -r '.usageMetadata.promptTokenCount // 0' 2>/dev/null || echo 0)
      TOTAL_CANDIDATES_TOKENS=$(echo "$last_chunk_json" | jq -r '.usageMetadata.candidatesTokenCount // 0' 2>/dev/null || echo 0) # Candidates count from usageMetadata first
      TOTAL_THOUGHTS_TOKENS=$(echo "$last_chunk_json" | jq -r '.usageMetadata.thoughtsTokenCount // 0' 2>/dev/null || echo 0)
      TOTAL_TOTAL_TOKENS=$(echo "$last_chunk_json" | jq -r '.usageMetadata.totalTokenCount // 0' 2>/dev/null || echo 0)

      # Special case: Sometimes the final candidatesTokenCount is in usageMetadata, sometimes in the final candidate itself
      if [[ "$TOTAL_CANDIDATES_TOKENS" -eq 0 ]]; then
          local candidate_tokens=$(echo "$last_chunk_json" | jq -r '.candidates[0].tokenCount // 0' 2>/dev/null || echo 0)
          if [[ "$candidate_tokens" -gt 0 ]]; then
             TOTAL_CANDIDATES_TOKENS=$candidate_tokens
          fi
      fi

      # Correct potential jq errors resulting in null/empty strings to 0
      [[ "$TOTAL_PROMPT_TOKENS" == "null" || -z "$TOTAL_PROMPT_TOKENS" ]] && TOTAL_PROMPT_TOKENS=0
      [[ "$TOTAL_CANDIDATES_TOKENS" == "null" || -z "$TOTAL_CANDIDATES_TOKENS" ]] && TOTAL_CANDIDATES_TOKENS=0
      [[ "$TOTAL_THOUGHTS_TOKENS" == "null" || -z "$TOTAL_THOUGHTS_TOKENS" ]] && TOTAL_THOUGHTS_TOKENS=0
      [[ "$TOTAL_TOTAL_TOKENS" == "null" || -z "$TOTAL_TOTAL_TOKENS" ]] && TOTAL_TOTAL_TOKENS=0
    fi
  fi

  if [[ "$finish_reason" != "STOP" ]]; then
    echo ""
    echo "------------------------------------------------------------"
    echo "⚠️  Warning: Transcription may be incomplete or errored!"
    echo "   Detected Finish Reason: $finish_reason (Expected: STOP)"
    echo "------------------------------------------------------------"
  fi

  # Check if the markdown output file is empty *after* the finish reason check
  if [[ ! -s "$MARKDOWN_OUTPUT_FILE" ]]; then
    echo ""
    echo "--------------------------------------------------"
    echo "❌ Error: The transcript file is empty!"
    echo "   This often happens if the API call failed."
    echo "   Showing contents of the raw API output (may contain error details):"
    echo "--------------------------------------------------"
    if [[ -f "$RAW_OUTPUT_FILE" ]]; then
      cat "$RAW_OUTPUT_FILE"
    else
      echo "[Raw output file not found: $RAW_OUTPUT_FILE]"
    fi
    echo "--------------------------------------------------"
    exit 1 # Exit here as an empty transcript is a definite failure
  fi

  # Only show success message if finish_reason was STOP or if it wasn't STOP but markdown is not empty
  if [[ -s "$MARKDOWN_OUTPUT_FILE" ]]; then
      echo ""
      echo "--------------------------------------------------"
      if [[ "$finish_reason" == "STOP" ]]; then
          echo "✅ Transcription Complete"
      else
          echo "ℹ️  Transcription Process Finished"
      fi
      echo "--------------------------------------------------"
      echo "  Raw API Output:       $RAW_OUTPUT_FILE"
      echo "  Transcript:           $MARKDOWN_OUTPUT_FILE"
      echo "--------------------------------------------------"
      # Updated token usage summary
      echo "📊 Token Usage '$LLM_MODEL'"
      echo "  ├─ Prompt:    ${TOTAL_PROMPT_TOKENS}"
      echo "  ├─ Response:  ${TOTAL_CANDIDATES_TOKENS}"
      echo "  ├─ Thoughts:  ${TOTAL_THOUGHTS_TOKENS}"
      echo "  └─ Total:     ${TOTAL_TOTAL_TOKENS}"
      echo "--------------------------------------------------"
  fi
}

# Execute main function
main "$@"

exit 0 