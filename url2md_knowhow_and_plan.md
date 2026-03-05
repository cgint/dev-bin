# url2md.py - Know-How and Enhancement Plan

## Current State

`url2md.py` is a UV script that fetches a URL and converts HTML to Markdown using Pandoc.

**Current flags:**
- `--clean` - Pre-Pandoc HTML cleaning (removes styles, unwraps divs, strips presentation attributes)
- `-o/--output` - Write to file instead of stdout
- `--timeout`, `--user-agent`, `--from-format` - Standard options

**Dependencies:** `requests`, `pypandoc`, `beautifulsoup4`, `lxml`

### Disallowed Domains

**github.com** (and subdomains like www, docs, gist) is disallowed. GitHub UI HTML converts poorly to Markdown and yields noisy, unusable output. For repo content use `raw.githubusercontent.com` or `git clone`. The script enforces this at runtime.

---

## Problem Analysis

Testing revealed that even with `--clean`, the output contains noise:

1. **Base64 embedded images**: `![](data:image/svg+xml;base64,PHN2...)`
2. **Pandoc fenced-div markers**: Lines of `:::::::` or `========`
3. **Pandoc attribute blocks**: `{.class #id attr="value" ...}`
4. **Tracking/hydration attributes**: `{hydro-click="..." hydro-click-hmac="..."}`
5. **Empty link constructs**: `[]{pjax-replace="" turbo-replace="" ...}`
6. **UI chrome**: Navigation, login prompts, star/fork buttons (on heavy sites like GitHub)

---

## Cleaning Strategy Tiers

### Tier 1: Safe (Always Applicable)

These patterns are universally safe to remove from **markdown output** (post-Pandoc):

| Pattern | Regex | Rationale |
|---------|-------|-----------|
| Base64 images | `!\[.*?\]\(data:image/[^)]+\)` | Never useful as text |
| Linked base64 images | `\[!\[.*?\]\(data:image/[^)]+\)\]` | Icon+link combos, noise |
| Pandoc div fences | `^:{3,}\s*$` | Fenced-div artifacts |
| Pandoc attribute blocks | `\{[^}]*\}` after links/headings | Metadata noise |
| Empty attribute links | `\[\]\{[^}]+\}` | Tracking garbage |
| Excessive blank lines | `\n{4,}` → `\n\n\n` | Cosmetic cleanup |
| Very long no-space lines | Lines >1000 chars with no spaces | Leaked minified JS/hashes |

**Key principle:** These are applied to the **markdown output**, not the HTML input. This separates concerns and avoids breaking Pandoc's conversion.

### Tier 2: Risky (Opt-in Only)

These could remove legitimate content on some sites:

| Approach | Risk |
|----------|------|
| Extract only `<article>` or `<main>` | Sites may misuse these tags or have multiple |
| Remove by CSS class (nav, sidebar, footer) | Class names vary wildly |
| Remove by tag name (header, footer, nav) | Could contain legitimate content |
| Heuristic text-density filtering | May remove sparse but important content |

### Tier 3: Smart (External Dependencies)

| Approach | Dependency | Notes |
|----------|------------|-------|
| Mozilla Readability | `readability-lxml` (Python) | Battle-tested, used in Firefox Reader Mode |
| Markitdown | External `uvx markitdown` | Good for PDFs/Office, not for HTML→MD |
| LLM-based cleaning | API key + cost | Best quality but violates "no LLM" goal |

---

## Agent Feedback

Real-world usage revealed another issue:

**Problem:** When fetching `https://github.com/.../blob/.../file.md`, we get the entire GitHub UI (navbar, buttons, file browser) instead of just the document content.

**Agent's solution:** Use the raw URL instead:
```
https://github.com/user/repo/blob/branch/path.md
→ https://raw.githubusercontent.com/user/repo/branch/path.md
```

**Insight:** For known platforms (GitHub, GitLab, Bitbucket), we can detect blob/file URLs and automatically transform them to raw URLs before fetching.

### Platform URL Transformations (Tier 1 - Safe)

| Platform | Input pattern | Transform to |
|----------|---------------|--------------|
| GitHub | `github.com/{user}/{repo}/blob/{branch}/{path}` | `raw.githubusercontent.com/{user}/{repo}/{branch}/{path}` |
| GitLab | `gitlab.com/{user}/{repo}/-/blob/{branch}/{path}` | `gitlab.com/{user}/{repo}/-/raw/{branch}/{path}` |
| Bitbucket | `bitbucket.org/{user}/{repo}/src/{branch}/{path}` | `bitbucket.org/{user}/{repo}/raw/{branch}/{path}` |

This is safe because:
1. Deterministic URL pattern matching
2. Always improves output for text/markdown files
3. Doesn't remove content - fetches better content

**Implementation:**

```python
def transform_to_raw_url(url: str) -> str:
    """Transform known platform URLs to their raw equivalents."""
    import re
    
    # GitHub: github.com/user/repo/blob/branch/path → raw.githubusercontent.com/user/repo/branch/path
    github_match = re.match(
        r'https://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)',
        url
    )
    if github_match:
        user, repo, branch, path = github_match.groups()
        return f'https://raw.githubusercontent.com/{user}/{repo}/{branch}/{path}'
    
    # GitLab: gitlab.com/user/repo/-/blob/branch/path → gitlab.com/user/repo/-/raw/branch/path
    gitlab_match = re.match(
        r'(https://[^/]*gitlab[^/]*/[^/]+/[^/]+)/-/blob/(.+)',
        url
    )
    if gitlab_match:
        base, rest = gitlab_match.groups()
        return f'{base}/-/raw/{rest}'
    
    # Bitbucket: bitbucket.org/user/repo/src/branch/path → bitbucket.org/user/repo/raw/branch/path
    bitbucket_match = re.match(
        r'(https://bitbucket\.org/[^/]+/[^/]+)/src/(.+)',
        url
    )
    if bitbucket_match:
        base, rest = bitbucket_match.groups()
        return f'{base}/raw/{rest}'
    
    return url  # No transformation
```

**Important insight:** Fetching a `.md` file through its rendered HTML page and converting back to Markdown is fundamentally wrong - it's a lossy round-trip. For markdown/text files:

**Note on heavy JS web apps (GitHub, Twitter, etc.):**
GitHub and similar web apps are not good use cases for this tool. They render content inside complex UI chrome (navigation, buttons, tracking attributes) that pollutes the output. For GitHub specifically:
- For `.md` files: Use raw URLs (`raw.githubusercontent.com/...`)
- For READMEs: Use the API or raw URL
- The rendered blob page is a web app, not content

We removed GitHub from the test suite for this reason - it's not the intended use case.

For markdown/text files:

1. Detect file extension from URL (`.md`, `.markdown`, `.txt`, `.rst`, `.json`, `.yaml`, etc.)
2. Transform to raw URL automatically
3. **Skip Pandoc entirely** - just return the raw content

```python
TEXT_EXTENSIONS = {'.md', '.markdown', '.txt', '.rst', '.json', '.yaml', '.yml', '.toml', '.csv'}

def is_text_file_url(url: str) -> bool:
    """Check if URL points to a known text file."""
    from urllib.parse import urlparse
    path = urlparse(url).path.lower()
    return any(path.endswith(ext) for ext in TEXT_EXTENSIONS)

# In main():
if is_text_file_url(url):
    url = transform_to_raw_url(url)
    content = fetch_html(url)  # Just raw text, no HTML
    # Skip Pandoc, output directly
    print(content)
else:
    # Normal HTML→Markdown flow
    ...
```

**CLI behavior:**
- Auto-detect text files and fetch raw (no flag needed)
- `--force-convert` flag to override and run through Pandoc anyway (edge cases)

---

## Proposed Implementation

### Option A: Post-processing regex cleanup (Recommended first step)

Add a `--postclean` flag that applies Tier 1 safe patterns to the markdown output:

```python
def postclean_markdown(md: str) -> str:
    """Apply safe regex patterns to clean markdown output."""
    import re
    
    # Remove base64 images (including linked ones)
    md = re.sub(r'\[?!\[.*?\]\(data:image/[^)]+\)\]?(\([^)]*\))?', '', md)
    
    # Remove Pandoc fenced-div markers (lines of ::: only)
    md = re.sub(r'^:{3,}\s*$', '', md, flags=re.MULTILINE)
    
    # Remove Pandoc attribute blocks {.class #id ...}
    md = re.sub(r'\{[^{}]*\}', '', md)
    
    # Remove empty links with attributes []{...}
    md = re.sub(r'\[\]\{[^}]+\}', '', md)
    
    # Collapse excessive blank lines
    md = re.sub(r'\n{4,}', '\n\n\n', md)
    
    # Remove very long lines without spaces (likely tokens/hashes)
    lines = md.split('\n')
    lines = [l for l in lines if len(l) < 1000 or ' ' in l]
    md = '\n'.join(lines)
    
    return md.strip()
```

**CLI change:**
```
url2md.py <url>                    # raw Pandoc output
url2md.py --clean <url>            # pre-Pandoc HTML cleaning
url2md.py --clean --postclean <url> # both cleaning phases
```

### Option B: Readability integration (Future)

Add `--readability` flag using `readability-lxml`:

```python
# Only if --readability flag is set
from readability import Document
doc = Document(html)
html = doc.summary()  # Returns cleaned article HTML
```

**Dependency:** Add `readability-lxml` to PEP 723 deps.

**Trade-off:** Adds ~2MB dependency, but very reliable for article extraction.

### Option C: Pandoc flag tuning (Low effort)

Try passing better Pandoc options to reduce noise at source:

```python
pypandoc.convert_text(
    html,
    to="gfm",  # GitHub-Flavored Markdown instead of generic md
    format="html",
    extra_args=[
        "--wrap=none",           # No line wrapping
        "--markdown-headings=atx",  # Use # headings
    ]
)
```

---

## Implementation Priority

1. **First:** Add platform URL transformations (GitHub/GitLab/Bitbucket raw URLs) - immediate high value
2. **Second:** Add `--postclean` with Tier 1 safe patterns (low risk, immediate value)
3. **Third:** Test Pandoc flag tuning (`gfm`, `--wrap=none`)
4. **Fourth:** Consider `--readability` as opt-in for article-heavy sites
5. **Later:** Evaluate if Tier 2 risky patterns are ever needed

---

## Testing Approach

Use the existing `testing_tmp/test_url2md.sh` script with diverse URLs:

- **Simple sites:** ai4you.app, example.com
- **Documentation:** docs.python.org, docs.astral.sh
- **Heavy apps:** github.com, wikipedia.org
- **News/blogs:** Various article sites

Compare output sizes and readability across:
- Normal (no flags)
- `--clean`
- `--clean --postclean`

---

## Evaluation Framework

To avoid over-fitting and objectively measure improvements, we need automated evaluation.

### Quantitative Metrics

| Metric | What it measures | How to compute |
|--------|-----------------|----------------|
| **Line count** | Raw output size | `wc -l` |
| **Token count** | LLM context efficiency | `tiktoken` or word count approximation |
| **Noise pattern count** | Remaining artifacts | Count regex matches of known patterns |
| **Content-to-noise ratio** | Signal quality | `(total_chars - noise_chars) / total_chars` |
| **Heading preservation** | Structure retained | Count `#` heading lines |

### Noise Pattern Detection

```python
NOISE_PATTERNS = [
    (r'!\[.*?\]\(data:image/', "base64_images"),
    (r'^:{3,}\s*$', "pandoc_fences"),
    (r'\{[^{}]{10,}\}', "attribute_blocks"),  # >10 chars to avoid false positives
    (r'\[\]\{', "empty_attr_links"),
    (r'hydro-click|hovercard|turbo-frame', "tracking_attrs"),
]

def count_noise(md: str) -> dict[str, int]:
    """Count occurrences of each noise pattern."""
    import re
    counts = {}
    for pattern, name in NOISE_PATTERNS:
        counts[name] = len(re.findall(pattern, md, re.MULTILINE))
    return counts
```

### Content Preservation Check

Extract "anchor phrases" from the original page (title, headings) and verify they survive cleaning:

```python
def check_content_preserved(md: str, expected_phrases: list[str]) -> float:
    """Return fraction of expected phrases found in output."""
    found = sum(1 for p in expected_phrases if p.lower() in md.lower())
    return found / len(expected_phrases) if expected_phrases else 1.0
```

### Golden File Testing

For regression prevention:

1. Save a "known-good" cleaned output for each test URL
2. On each change, re-run cleaning and diff against golden file
3. Review diffs manually
4. Update golden if improvement, reject if regression

### Evaluation Report Format

```
┌─────────────────────────────────────────────────────────────────┐
│ URL: https://ai4you.app                                         │
├─────────────────────────────────────────────────────────────────┤
│                    │ Normal │ --clean │ --postclean │ Change   │
├─────────────────────────────────────────────────────────────────┤
│ Lines              │    292 │     139 │         125 │ -57%     │
│ Tokens (~)         │   4200 │    2100 │        1900 │ -55%     │
│ Noise patterns     │     47 │      12 │           2 │ -96%     │
│ Content preserved  │   100% │    100% │        100% │ OK       │
│ Headings found     │      8 │       8 │           8 │ OK       │
└─────────────────────────────────────────────────────────────────┘
```

### Test URL Categories

Ensure diverse coverage to avoid over-fitting to specific site types:

| Category | URLs | Why |
|----------|------|-----|
| Simple/clean | ai4you.app, example.com | Baseline, should work perfectly |
| Documentation | docs.python.org, docs.astral.sh | Important use case for agents |
| Heavy JS apps | github.com, twitter.com | Stress test, expect some noise |
| News/blogs | Medium, dev.to articles | Article extraction scenario |
| Wikipedia | wikipedia.org | Dense content, good structure |

### Evaluation Script

Create `testing_tmp/evaluate_url2md.py` that:

1. Runs all test URLs through each mode (normal, --clean, --postclean)
2. Computes all metrics for each output
3. Outputs comparison table
4. Saves results to JSON for tracking over time
5. Optionally diffs against golden files

---

## Open Questions

1. Should `--postclean` be on by default, or always opt-in?
2. Is `gfm` output format better than `md` for agent consumption?
3. Should we add `--readability` now or wait for user demand?
4. Are there Pandoc plugins/filters that already handle some of this?
5. What threshold of "content preserved" is acceptable? (99%? 95%?)
6. Should we track metrics over time in a simple JSON/CSV file?

---

## Evaluation Process

Each iteration follows this process:

1. **Run test suite:** `testing_tmp/test_url2md.sh` on diverse URLs
2. **Compute metrics:** `testing_tmp/evaluate_detailed.py --all` for noise patterns and samples
3. **LLM assessment:** Provide context + metrics to LLM for independent review
4. **Human assessment:** Add short text analysis with confidence level
5. **Document in history:** Update `testing_tmp/evaluation_history.md` with timestamped results
6. **Track changes:** Log what changed and its impact

**Anti-gaming checks:**
- Show actual samples of detected "noise" (human can verify it's garbage)
- Track heading counts (must not drop - indicates content loss)
- Track first paragraph extraction (must have readable content)
- Preserve evaluation history for comparison

---

## References

- [Mozilla Readability](https://github.com/mozilla/readability) - Firefox Reader Mode algorithm
- [readability-lxml](https://pypi.org/project/readability-lxml/) - Python port
- [summarize project](https://github.com/steipete/summarize) - Uses Readability + LLM fallback
- [Pandoc User Guide](https://pandoc.org/MANUAL.html) - Output format options
- `testing_tmp/evaluation_history.md` - Timestamped evaluation results and assessments
