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
  url2md.py <url|file> --no-strip-residual-html  # keep leftover HTML in prose
  url2md.py <url|file> --to-format md  # Pandoc output format (default: gfm)

Options:
  --to-format FORMAT   Pandoc output format (e.g. gfm, md, commonmark).
                       Default: gfm (GitHub Flavored Markdown).
  --from-format FORMAT Pandoc input format (default: html).

Pandoc must be installed (e.g. brew install pandoc).

Do not use for github.com: GitHub UI HTML converts poorly to Markdown.
For repo files use raw.githubusercontent.com or git clone.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import NoReturn
from urllib.parse import urlparse

import requests
from bs4 import BeautifulSoup, Tag

DEFAULT_TIMEOUT = 15
DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
)

_PANDOC_EXTRA_ARGS = ("--wrap=none", "--markdown-headings=atx")


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
    import pypandoc

    try:
        pypandoc.get_pandoc_path()
    except OSError:
        _die("Pandoc is not installed. Install it first (e.g. brew install pandoc).")


def _is_hexdocs_host(host: str) -> bool:
    h = host.lower().split(":")[0]
    return h == "hexdocs.pm" or h.endswith(".hexdocs.pm")


def input_suggests_hexdocs(input_arg: str) -> bool:
    """True when fetching from hexdocs.pm (used for ExDoc-specific pre-clean)."""
    if not input_arg.startswith(("http://", "https://")):
        return False
    return _is_hexdocs_host(urlparse(input_arg).netloc or "")


def _hexdocs_strip_chrome(root: Tag) -> None:
    """Remove ExDoc/HexDocs UI inside main: search bar, copy-markdown, view-source."""
    for el in root.select(".top-search"):
        el.decompose()
    for el in root.select("a.copy-markdown"):
        el.decompose()
    for el in root.select('a[title="View Source"], a[title*="View Source"]'):
        el.decompose()
    # Fallback: sidebar sr-only labels sometimes leak as adjacent text
    for el in root.select("#sidebar"):
        el.decompose()
    # ExDoc appends package links / ExDoc credit inside <main>
    for el in root.find_all("footer"):
        el.decompose()


def _pick_content_root(soup: BeautifulSoup, *, extract_main: bool) -> Tag:
    if extract_main:
        main = soup.find("main", id="main") or soup.find("main")
        if isinstance(main, Tag):
            return main
    body = soup.body
    if isinstance(body, Tag):
        return body
    return soup if isinstance(soup, Tag) else soup.find("body") or soup


def _strip_dynamic_attributes(root: Tag) -> None:
    """Remove data-*, aria-*, and other noisy attrs; extend fixed deny list."""
    fixed_remove = {
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
        "translate",
        "role",
        "tabindex",
        "hidden",
    }
    # find_all(True) does not include the root node; strip root explicitly.
    for t in (root, *root.find_all(True)):
        attrs = dict(t.attrs)
        for attr in attrs:
            if attr in fixed_remove or attr.startswith("data-") or attr.startswith("aria-"):
                del t[attr]


def _unwrap_all(root: Tag, name: str) -> None:
    """Repeatedly unwrap elements of name until none remain (inner-first via iterative peel)."""
    while True:
        el = root.find(name)
        if el is None:
            break
        el.unwrap()


def _remove_wbr(root: Tag) -> None:
    """Remove <wbr> (line-break opportunities); ExDoc uses them inside module names.
    Use unwrap(), not replace_with(''): lxml may parse <wbr>Form</wbr> and dropping the
    node would delete the following text.
    """
    for wbr in list(root.find_all("wbr")):
        wbr.unwrap()


def _remove_empty_phrasing(root: Tag) -> None:
    for name in ("em", "strong", "i", "b"):
        for t in list(root.find_all(name)):
            if not t.get_text(strip=True):
                t.decompose()


def _remove_empty_anchors(root: Tag) -> None:
    """Remove icon-only or placeholder links (e.g. ExDoc view-source anchors with no text)."""
    for a in list(root.find_all("a")):
        if a.get_text(strip=True):
            continue
        if a.find("img"):
            continue
        a.decompose()


def clean_html_string(
    html: str,
    *,
    hexdocs: bool = False,
    extract_main: bool = True,
) -> str:
    """
    Clean HTML by removing styles, unwrapping divs/spans, stripping attributes.
    When hexdocs=True, strip ExDoc chrome and prefer <main id="main"> when extract_main.
    """
    soup = BeautifulSoup(html, "lxml")

    tags_to_remove = soup.find_all(["style", "meta", "script", "svg"])
    stylesheet_links = soup.find_all("link", rel="stylesheet")
    tags_to_remove.extend(stylesheet_links)

    for tag in tags_to_remove:
        tag.decompose()

    root = _pick_content_root(soup, extract_main=extract_main)
    if hexdocs:
        _hexdocs_strip_chrome(root)

    _unwrap_all(root, "div")
    _strip_dynamic_attributes(root)

    _unwrap_all(root, "span")
    _remove_wbr(root)
    _unwrap_all(root, "small")
    _unwrap_all(root, "section")
    _remove_empty_phrasing(root)
    _remove_empty_anchors(root)

    # Serialize only the doc column: do not unwrap <main> in-place (siblings like sidebar would reappear).
    if root.name == "main":
        return root.decode_contents()
    return str(root)


def html_to_markdown(html: str, from_format: str = "html", to_format: str = "gfm") -> str:
    """Convert HTML string to Markdown using Pandoc."""
    import pypandoc

    return pypandoc.convert_text(
        html,
        to=to_format,
        format=from_format,
        encoding="utf-8",
        extra_args=list(_PANDOC_EXTRA_ARGS),
    )


def _strip_residual_html_outside_fences(md: str) -> str:
    """
    Remove simple leftover HTML tags in prose only (not inside fenced code blocks).
    Conservative: line-based, may miss multi-line tags.
    """
    lines = md.split("\n")
    out: list[str] = []
    in_fence = False
    # Unwrap common inline wrappers repeatedly
    tag_pattern = re.compile(
        r"<(span|div|small|wbr)(?:\s[^>]*)?>(.*?)</\1>",
        re.IGNORECASE | re.DOTALL,
    )

    for line in lines:
        stripped = line.strip()
        if stripped.startswith("```"):
            in_fence = not in_fence
            out.append(line)
            continue
        if in_fence:
            out.append(line)
            continue
        s = line
        for _ in range(32):
            new = tag_pattern.sub(r"\2", s)
            if new == s:
                break
            s = new
        # Void wbr often appears alone
        s = re.sub(r"<wbr\s*/?>", "", s, flags=re.IGNORECASE)
        out.append(s)
    return "\n".join(out)


def postclean_markdown(md: str, *, strip_residual_html: bool = True) -> str:
    """
    Apply safe regex patterns to clean markdown output (post-Pandoc).
    Goal: remove common conversion artifacts without removing real content.
    """
    # Remove HTML comments
    md = re.sub(r"<!--[\s\S]*?-->", "", md)

    # Remove base64 images (including linked ones)
    md = re.sub(r"\[?!\[[^\]]*\]\(data:image/[^)]+\)\]?(?:\([^)]*\))?", "", md)

    # Remove Pandoc fenced-div markers (lines of ::: only)
    md = re.sub(r"^:{3,}\s*$", "", md, flags=re.MULTILINE)

    # Remove Pandoc attribute blocks {.class #id attr="value" ...}
    md = re.sub(r"\{[^{}]{10,}\}", "", md)

    # Remove empty links with attributes []{...}
    md = re.sub(r"\[\]\{[^}]+\}", "", md)

    # Remove smaller attribute blocks that are clearly noise
    md = re.sub(r'\{(?:target|rel|aria-[a-z]+|data-[a-z-]+)="[^"]*"\}', "", md)

    # Collapse excessive blank lines (more than 2 consecutive)
    md = re.sub(r"\n{4,}", "\n\n\n", md)

    # Remove very long lines without spaces (likely tokens/hashes >500 chars)
    lines = md.split("\n")
    lines = [line for line in lines if len(line) < 500 or " " in line]
    md = "\n".join(lines)

    if strip_residual_html:
        md = _strip_residual_html_outside_fences(md)

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
    parser.add_argument(
        "--no-extract-main",
        action="store_true",
        help="Do not narrow to <main> even on HexDocs (use full <body>).",
    )
    parser.add_argument(
        "--extract-main",
        action="store_true",
        help="Narrow to <main> when present (for any site; default on for hexdocs.pm only).",
    )
    parser.add_argument(
        "--no-strip-residual-html",
        action="store_true",
        help=(
            "Do not strip simple leftover HTML tags in prose (outside fenced code). "
            "By default, such tags are removed after conversion."
        ),
    )
    args = parser.parse_args()

    ensure_pandoc()
    html = read_html_from_input(
        args.input, timeout=args.timeout, user_agent=args.user_agent
    )

    hexdocs = input_suggests_hexdocs(args.input)
    if args.no_extract_main:
        extract_main = False
    elif args.extract_main:
        extract_main = True
    else:
        extract_main = hexdocs

    use_clean = not args.no_clean
    use_postclean = not args.no_postclean

    if use_clean:
        html = clean_html_string(html, hexdocs=hexdocs, extract_main=extract_main)

    md = html_to_markdown(html, from_format=args.from_format, to_format=args.to_format)
    if use_postclean:
        md = postclean_markdown(
            md, strip_residual_html=not args.no_strip_residual_html
        )

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(md)
    else:
        print(md, end="")


if __name__ == "__main__":
    main()
