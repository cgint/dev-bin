---
name: my-tools-toolbox
description: The toolbox (webs.sh for web-search, asks.sh for documentation- and code-search, speaks.sh for text-to-speech, url2md.py, pi-session-to-md, ...)
---
# CLI Tools Catalog
# Run <tool> -h for detailed usage information

--- AI & LLM TOOLS ---

- gem.sh              Wrapper for Gemini CLI with model shortcuts (flash/pro/lite) ::: Example: gem.sh -p "analyse file and extract relevant information" (use as sub agent)
- webs.sh             Web search via Gemini with grounding; accepts file + prompt, outputs to stdout or file ::: Example: webs.sh "latest AI news" ::: Allow at least **180s** (180000 ms) per run; on timeout retry with a higher limit before giving up
- asks.sh             Query documentation using BM25 search and generate answers by topic ::: Example: asks.sh my-sourcecode "Where doe we use Gemini Live API" ::: list of topics by simply running asks.sh
- codegiant.py        Orchestrates context collection and LLM interaction for code tasks ::: Example: codegiant.py -y -o diff_review.md -t "review the diff.txt - Only reports real issues" -e py,js,txt,html
- codecollector.py    Gathers project context into a single markdown file for LLM consumption ::: Example: codecollector.py -y -o context.md
- aider.sh            Launches aider AI coding assistant with preconfigured environment ::: Example: aider.sh
- speaks.sh           Text-to-speech using AI; reads text or files aloud ::: Example: speaks

--- CODE & PROJECT SEARCH ---

- dev_find.sh         Search file contents across ~/dev for a query (grep with smart defaults) ::: Example: dev_find.sh "gemini-2.0-" py toml ts js java
- dev_file_find.sh    Search for filenames containing a pattern across ~/dev ::: Example: dev_file_find.sh "config"
- dev_last_edit.sh    List recently modified files with date/extension filters ::: Example: dev_last_edit.sh --today
- dev_history_find.sh Search native AI session stores and export sessions ::: Example: dev_history_find.sh "here and derive what this is meant for"
- ctags_symbol_map.py Extract class/function/method symbols using Universal Ctags ::: Example: ctags_symbol_map.py .

--- DIAGRAMS & VISUALIZATION ---

- d2to.sh             Convert D2 diagram files to SVG (local or Docker) ::: Examples: d2to.sh meeting.d2 same as d2to.sh meeting.d2 meeting_down.svg
- plantuml.sh         Convert PlantUML files to SVG/PNG using Docker ::: Example: plantuml.sh diagram.puml

--- AUDIO & MEDIA ---

- mptranscribe.sh     Transcribe audio files using Gemini API with detailed output ::: Example: mptranscribe.sh audio.mp3

--- HTML & WEB ---

- agent-browser       Browser automation CLI (installed system-wide). Use -h for detailed instructions. Chain multiple commands in a single one-line shell execution for speed ::: Example: agent-browser set viewport 1024 768 && agent-browser open <url> && agent-browser screenshot ./openspec/.../<useful-name>.png
- url2md.py           Fetch URL and convert HTML to Markdown (Pandoc required); default stdout for agents ::: Example: url2md.py https://example.com ::: url2md.py <url> -o out.md ::: Do not use for github.com
- html_cleaner.sh     Clean HTML files, optionally minify, using BeautifulSoup ::: Example: html_cleaner.sh input.html output.html

--- UTILITIES ---

- timeout.sh          Run a command with a timeout in seconds ::: Example: timeout.sh 4 >server-startup-logs-check>
