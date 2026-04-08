---
name: web-search
description: Search the web using Gemini with grounding through webs.sh and url2md.py
---

# Web Search & AI-grounded Results

This skill provides AI-powered web search capabilities with grounding through Gemini CLI.

## Tools

**webs.sh** - Web search via Gemini with grounding; accepts file + prompt, outputs to stdout or file.

**url2md.py** - Fetch a URL and convert its HTML to Markdown (Pandoc required). Default: print markdown to stdout (suitable for agents). Use `-o FILE` to write to a file. Do not use for github.com (use raw.githubusercontent.com or git clone for repo content).

## Usage

```bash
webs.sh "<search-query>"
```

```bash
# Web page to Markdown (UV script; Pandoc required)
url2md.py <url>           # print markdown to stdout (e.g. for agents)
url2md.py <url> -o out.md # write to file
```

## Examples

```bash
# Search for latest AI news
webs.sh "latest AI news"

# Search with file input
webs.sh analysis.txt "analyze this information"

# Output to stdout (default)
webs.sh "gemini-3-flash model capabilities"
```

```bash
# Fetch page as markdown (default: stdout for agent use)
url2md.py https://example.com/docs

# Save to file
url2md.py https://example.com/docs -o docs.md
```

---  

## When to Use This Skill

Use `webs.sh` when you need to:
- Search the web for current information
- Ground AI responses in real-time web content
- Gather up-to-date information on technical topics
- Get summarised information from multiple sources
- Combine web search with file analysis

Use `url2md.py` when you need to:
- Fetch a single URL and get its content as Markdown (e.g. for agent consumption)
- Convert a known page to Markdown without search (Pandoc must be installed)

Do NOT use `url2md.py` for github.com: GitHub UI HTML converts poorly to Markdown.

---  

## How It Works

`webs.sh` leverages "grounding" which means it ties AI responses directly to real web sources, making outputs more reliable and traceable compared to standard AI queries.

---  

## Best Practices

- **Keep queries focused**: Be specific with your search terms for better results
- **Use natural language**: The tool understands complex queries well
- **Follow up with analysis**: Combine search results with file analysis when you have one (just add the file as first argument)
- **Save results when**: If you're working on important research, consider capturing output:
  ```bash
  webs.sh "your query" > results.txt
  ```

---  

## Timeouts and retries (important)

Grounded web search is slow (fetching sources plus model work). Short shell or tool timeouts (for example **60s**) often fail even when the command would have succeeded.

- **Default budget**: When your environment lets you set how long a command may run, use at least **180 seconds** for `webs.sh` (in millisecond-based UIs, that is **180000 ms**).
- **If the run ends with a timeout**: Treat it as “not enough time,” not as “search is broken.” **Retry once** with a **longer** limit (for example **300s** / **300000 ms**) before abandoning web search or telling the user search is unavailable.
- **Do not** give up on the user’s request only because the first run hit a low timeout.

---  

## Tips

- Check `webs.sh -h` for detailed usage information
- Results are processed by AI to provide contextual summaries
- The grounding aspect helps validate and cite information sources
- Performance depends on your network and Gemini API access
- For `url2md.py`: omit `-o` to print markdown to stdout (ideal for agents); requires Pandoc (e.g. `brew install pandoc`); do not use for github.com (use raw.githubusercontent.com or git clone)