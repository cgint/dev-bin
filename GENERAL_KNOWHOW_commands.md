
# Commands

## Aliases
```bash
alias gemp="gem.sh pro"
alias gemf="gem.sh flash"
alias gemgof="gem.sh flash -s --approval-mode auto_edit "
alias gemgop="gem.sh pro -s --approval-mode auto_edit"
alias gemyof="gem.sh flash -s -y "
alias gemyop="gem.sh pro -s -y "
alias gget="gget.sh"
alias uvall="uv sync --all-extras --all-groups"
alias aye="aider.sh --yes-always"
alias aider="aider.sh"
alias aiderf="aider --model vertex_ai/gemini-2.5-flash"
alias aiderfye="aye --model vertex_ai/gemini-2.5-flash"
alias timeout="timeout.sh"
```

## Diagrams

```bash
mmdc -i data_flow_detailed.mmd -o data_flow_detailed.png -w 3000
mmdc -i data_flow_detailed.mmd -o data_flow_detailed.cvg
```

## Watches

### Diverse tools

**ruff check**

```bash
watchexec -w testing/pipeline -e py -- uv run ruff check --fix testing/pipeline
```

**mypy check**

```bash
watchexec -w testing/pipeline -e py -- uv run mypy testing/pipeline

```

**aider AI!**

```bash
cd testing/pipeline; aiderf --subtree-only --watch-files --read ../../GEMINI.md --no-suggest-shell-commands
```

**Watch:**

```bash
watchexec -e mmd mmdc -i data_flow_detailed.mmd -o data_flow_detailed.svg
```

### watches.sh for multiple tools

```bash
#!/bin/bash

##
# Usage examples that adapt the values in contrast to defaults:
#   - watches.sh -> runs with defaults
#   - watches.sh mypy -> sets ACTIVATE_MYPY=1
#   - watches.sh noruff -> sets ACTIVATE_RUFF=0
#   - watches.sh testing/transcribe -> sets PATH_TO_WATCH="testing/transcribe"
#   - watches.sh testing/transcribe mypy -> sets PATH_TO_WATCH="testing/transcribe" and ACTIVATE_MYPY=1
#   - watches.sh testing/transcribe nomypy -> sets PATH_TO_WATCH="testing/transcribe" and ACTIVATE_MYPY=0
#   - watches.sh testing/transcribe nomypy noruff -> sets PATH_TO_WATCH="testing/transcribe" and ACTIVATE_MYPY=0 and ACTIVATE_RUFF=0
##

# Defaults - NEVER CHANGE THOSE VALUES
PATH_TO_WATCH="testing/pipeline"
ACTIVATE_RUFF=1
ACTIVATE_MYPY=0

# Check params to update defaults if necessary
for arg in "$@"; do
  case "$arg" in
    mypy)
      ACTIVATE_MYPY=1
      ;;
    nomypy)
      ACTIVATE_MYPY=0
      ;;
    ruff)
      ACTIVATE_RUFF=1
      ;;
    noruff)
      ACTIVATE_RUFF=0
      ;;
    *)
      # If the argument is a directory, assume it's the path to watch.
      if [ -d "$arg" ]; then
        PATH_TO_WATCH="$arg"
      fi
      ;;
  esac
done

# Function to kill background processes
cleanup() {
    echo "Caught Ctrl-C. Killing background processes..."
    if [ -n "$PIDS" ]; then
        kill $PIDS
    fi
    exit 1
}

GEMINI_ABS_PATH="$(pwd)/GEMINI.md"

# Trap Ctrl-C (SIGINT) and call the cleanup function
trap cleanup SIGINT

# Start processes in the background and store their PIDs
if [ "$ACTIVATE_RUFF" -eq 1 ]; then
    watchexec -w "$PATH_TO_WATCH" -e py -- uv run ruff check --fix "$PATH_TO_WATCH" &
    PIDS="$PIDS $!"
fi

if [ "$ACTIVATE_MYPY" -eq 1 ]; then
    watchexec -w "$PATH_TO_WATCH" -e py -- uv run mypy "$PATH_TO_WATCH" &
    PIDS="$PIDS $!"
fi

cd $PATH_TO_WATCH; aider.sh --model vertex_ai/gemini-2.5-flash --subtree-only --watch-files --read $GEMINI_ABS_PATH --no-suggest-shell-commands

# Wait for all background processes to complete
#wait
cleanup

echo "All background processes completed."

```

# html/markdown/pdf - pandoc: Convert markdown, pdf, html, ...

## Convert and clean html

### could use sed

```bash
sed 's/<img[^>]*>//g' pr.html | pandoc --from html --to markdown --lua-filter ./no-images.lua -o pr2.md
```

### pandoc with lua filter

```bash
sed 's/<img[^>]*>//g' pr.html | pandoc --from html --to markdown --lua-filter ./no-images.lua -o pr2.md

pandoc pr.html --from html --to markdown --lua-filter ./no-images.lua -o pr2.md
pandoc pr.html --from html --to html --lua-filter ./no-images.lua -o pr2.html
```

**the lua filter**

```lua
function Image (el)
    return ""
end

function Script (el)
    return ""
end
```

### use gemini to extract information from cleaned html stored as markdown

```bash
gemgof -p "extract info from pr2.md and summarize the most important findings around usage of commands as citations and detailed information. write to file find_commands.md" -d
gemgof -p "extract info from pr2.md and summarize the most important findings around usage of commands as citations and detailed information. write to file find_commands.md" -d
gemgof -p "extract info from pr2.md and summarize the most important findings around usage of agents as citations and detailed information. write to file find_agents.md" -d
```

# rules, guides for LLM AI Agents

## Elixir, BEAM

### usage_rules

[https://hexdocs.pm/usage_rules/readme.html](https://hexdocs.pm/usage_rules/readme.html)

```bash
mix usage_rules.sync AG.md --all usage_rules:all --inline usage_rules:all --link-to-folder deps --remove-missing 

Notices: 

* Found 3 dependencies with usage rules
* Including usage rules for: phoenix:ecto
* Including usage rules for: phoenix:elixir
* Including usage rules for: phoenix:html
* Including usage rules for: phoenix:liveview
* Including usage rules for: phoenix:phoenix
* Including usage rules for: usage_rules
* Including usage rules for: usage_rules:elixir
* Including usage rules for: usage_rules:otp
* Including usage rules for: igniter

Notices were printed above. Please read them all before continuing!

Igniter - Warnings:

* Usage Rules:
  
  We've synchronized usage rules for all of your direct
  dependencies into AG.md. When working with agents, it
  is important to manage your context window. Consider
  which packages you wish to have present. You can use
  the `--remove-missing` flag to select exactly what to sync.
  
  For example:
  
      mix usage_rules.sync AG.md pkg1 pkg2 \
        usage_rules:all \
        --inline usage_rules:all \
        --link-to-folder deps \
        --remove-missing
```
