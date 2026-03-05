#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#     "requests>=2.28.0",
#     "pypandoc>=1.11",
#     "beautifulsoup4>=4.12.0",
#     "lxml>=4.9.0",
# ]
# requires-python = ">=3.11"
# ///

"""
Fetch a URL or read a local HTML file and convert to Markdown using Pandoc.

Usage:
  url2md.py <url>                  # fetch URL, print markdown to stdout
  url2md.py <file.html>             # read local HTML file
  url2md.py <url|file> -o out.md   # write to file
  url2md.py <url|file> --no-clean   # disable HTML pre-clean
  url2md.py <url|file> --no-postclean  # disable Markdown postclean
  url2md.py <url|file> --to-format md  # Pandoc output format (default: gfm)

Options:
  --to-format FORMAT   Pandoc output format (e.g. gfm, md, commonmark).
                       Default: gfm (GitHub Flavored Markdown).
  --from-format FORMAT Pandoc input format (default: html).

Pandoc must be installed (e.g. brew install pandoc).

Do not use for github.com: GitHub UI HTML converts poorly to Markdown.
For repo files use raw.githubusercontent.com or git clone.
"""

import argparse
import re
import sys
from pathlib import Path
from typing import NoReturn
from urllib.parse import urlparse

import requests
import pypandoc
from bs4 import BeautifulSoup


DEFAULT_TIMEOUT = 15
DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)


def fetch_html(
    url: str,
    timeout: int = DEFAULT_TIMEOUT,
    user_agent: str = DEFAULT_USER_AGENT,
) -> str:
    """Download URL and return response text."""
    headers = {"User-Agent": user_agent}
    resp = requests.get(url, headers=headers, timeout=timeout)
    resp.raise_for_status()
    resp.encoding = resp.encoding or "utf-8"
    return resp.text


def read_html_from_input(
    input_arg: str,
    timeout: int = DEFAULT_TIMEOUT,
    user_agent: str = DEFAULT_USER_AGENT,
) -> str:
    """Get HTML from URL or local file. Detects input type automatically."""
    if input_arg.startswith(("http://", "https://")):
        parsed = urlparse(input_arg)
        host = (parsed.netloc or "").lower()
        if host == "github.com" or host.endswith(".github.com"):
            _die(
                "url2md does not support github.com: GitHub UI HTML converts poorly to Markdown. "
                "For repo files use raw.githubusercontent.com or git clone."
            )
        return fetch_html(input_arg, timeout=timeout, user_agent=user_agent)
    path = Path(input_arg)
    if not path.exists():
        _die(f"File not found: {input_arg}")
    if not path.is_file():
        _die(f"Not a file: {input_arg}")
    return path.read_text(encoding="utf-8")


def ensure_pandoc() -> None:
    """Ensure Pandoc is available; raise SystemExit with clear message if not."""
    try:
        pypandoc.get_pandoc_path()
    except OSError:
        _die("Pandoc is not installed. Install it first (e.g. brew install pandoc).")


def clean_html_string(html: str) -> str:
    """
    Clean HTML by removing styles, unwrapping divs, and stripping presentation attributes.
    Returns cleaned HTML string.
    """
    soup = BeautifulSoup(html, "lxml")

    # 1. Remove <style>, <link rel="stylesheet">, <meta>, <script>, and inline <svg> tags
    #
    # Inline SVGs (often icons inside links/buttons) can confuse HTML→MD conversion
    # and lead to broken markdown like "- [Text" without a closing link.
    tags_to_remove = soup.find_all(["style", "meta", "script", "svg"])
    stylesheet_links = soup.find_all("link", rel="stylesheet")
    tags_to_remove.extend(stylesheet_links)

    for tag in tags_to_remove:
        tag.decompose()

    # 2. Unwrap <div> elements
    for tag in soup.find_all("div"):
        tag.unwrap()

    # 3. Remove presentation-related attributes from all remaining tags
    attributes_to_remove = [
        "style",
        "class",
        "id",
        "width",
        "height",
        "cellspacing",
        "cellpadding",
        "border",
        "dir",
        "valign",
    ]

    for tag in soup.find_all(True):
        attrs = dict(tag.attrs)
        for attr in attrs:
            if attr in attributes_to_remove:
                del tag[attr]

    # Return cleaned HTML
    body_content = soup.body if soup.body else soup
    return str(body_content)


def html_to_markdown(html: str, from_format: str = "html", to_format: str = "gfm") -> str:
    """Convert HTML string to Markdown using Pandoc."""
    return pypandoc.convert_text(
        html,
        to=to_format,
        format=from_format,
        encoding="utf-8",
    )


def postclean_markdown(md: str) -> str:
    """
    Apply safe regex patterns to clean markdown output (post-Pandoc).
    Goal: remove common conversion artifacts without removing real content.
    """
    # Remove base64 images (including linked ones)
    # Pattern: ![...](data:image/...) or [![...](data:...)](/link)
    md = re.sub(r"\[?!\[[^\]]*\]\(data:image/[^)]+\)\]?(?:\([^)]*\))?", "", md)

    # Remove Pandoc fenced-div markers (lines of ::: only)
    md = re.sub(r"^:{3,}\s*$", "", md, flags=re.MULTILINE)

    # Remove Pandoc attribute blocks {.class #id attr="value" ...}
    # Only remove blocks with >10 chars to avoid false positives like {n}
    md = re.sub(r"\{[^{}]{10,}\}", "", md)

    # Remove empty links with attributes []{...}
    md = re.sub(r"\[\]\{[^}]+\}", "", md)

    # Remove smaller attribute blocks that are clearly noise
    # Like {target="_blank"} or {rel="nofollow"}
    md = re.sub(r'\{(?:target|rel|aria-[a-z]+|data-[a-z-]+)="[^"]*"\}', "", md)

    # Collapse excessive blank lines (more than 2 consecutive)
    md = re.sub(r"\n{4,}", "\n\n\n", md)

    # Remove very long lines without spaces (likely tokens/hashes >500 chars)
    lines = md.split("\n")
    lines = [line for line in lines if len(line) < 500 or " " in line]
    md = "\n".join(lines)

    return md.strip()


def _die(message: str) -> NoReturn:
    print(message, file=sys.stderr)
    sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Fetch URL and convert HTML to Markdown (Pandoc required).",
        epilog="With no -o/--output, markdown is printed to stdout (suitable for agents).",
    )
    parser.add_argument(
        "input",
        metavar="URL_OR_FILE",
        help="URL to fetch or path to local HTML file",
    )
    parser.add_argument(
        "-o",
        "--output",
        metavar="FILE",
        help="Write markdown to FILE; default is stdout",
    )
    clean_group = parser.add_mutually_exclusive_group()
    clean_group.add_argument(
        "--clean",
        action="store_true",
        help="Enable HTML pre-clean (default: enabled)",
    )
    clean_group.add_argument(
        "--no-clean",
        action="store_true",
        help="Disable HTML pre-clean",
    )
    postclean_group = parser.add_mutually_exclusive_group()
    postclean_group.add_argument(
        "--postclean",
        action="store_true",
        help="Enable Markdown postclean (default: enabled)",
    )
    postclean_group.add_argument(
        "--no-postclean",
        action="store_true",
        help="Disable Markdown postclean",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=DEFAULT_TIMEOUT,
        help=f"Request timeout in seconds (default: {DEFAULT_TIMEOUT})",
    )
    parser.add_argument(
        "--user-agent",
        default=DEFAULT_USER_AGENT,
        help="HTTP User-Agent (default: Chrome-like)",
    )
    parser.add_argument(
        "--from-format",
        default="html",
        metavar="FORMAT",
        help="Pandoc input/source format (default: html)",
    )
    parser.add_argument(
        "--to-format",
        default="gfm",
        metavar="FORMAT",
        help="Pandoc output format, e.g. gfm, md, commonmark (default: gfm)",
    )
    args = parser.parse_args()

    ensure_pandoc()
    html = read_html_from_input(
        args.input, timeout=args.timeout, user_agent=args.user_agent
    )
    
    # Defaults: clean + postclean enabled; flags allow opting out.
    use_clean = not args.no_clean
    use_postclean = not args.no_postclean

    if use_clean:
        html = clean_html_string(html)
    
    md = html_to_markdown(html, from_format=args.from_format, to_format=args.to_format)
    if use_postclean:
        md = postclean_markdown(md)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(md)
    else:
        print(md, end="")


if __name__ == "__main__":
    main()
