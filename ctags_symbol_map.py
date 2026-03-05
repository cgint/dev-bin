#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from typing import Any, Iterable, Optional


DEFAULT_EXCLUDES = [
    ".git",
    ".hg",
    ".svn",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    "__pycache__",
    ".venv",
    "venv",
    "env",
    "node_modules",
    "build",
    "dist",
]


def _parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract class/function/method symbols across languages using Universal Ctags (JSON)."
    )
    parser.add_argument("paths", nargs="*", default=["."], help="Files/directories (default: .).")
    parser.add_argument(
        "--languages",
        default="Python,Java,TypeScript",
        help="Comma-separated ctags languages to include (default: Python,Java,TypeScript).",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help="Exclude pattern (repeatable). Defaults include .git, .venv, node_modules, etc.",
    )
    parser.add_argument(
        "--format",
        choices=("lines", "json"),
        default="lines",
        help="Output format (default: lines).",
    )
    parser.add_argument(
        "--include-kinds",
        default="class,interface,enum,module,macro,method,member,function",
        help="Comma-separated kinds to keep (default: class,interface,enum,method,member,function).",
    )
    return parser.parse_args(argv)


def _require_universal_ctags() -> None:
    try:
        out = subprocess.check_output(["ctags", "--version"], text=True, stderr=subprocess.STDOUT)
    except FileNotFoundError as exc:
        raise SystemExit("ctags not found in PATH. Install Universal Ctags (Homebrew: brew install universal-ctags).") from exc

    if "Universal Ctags" not in out:
        raise SystemExit(
            "ctags in PATH is not Universal Ctags.\n"
            "On macOS, install it via Homebrew and ensure /opt/homebrew/bin is before /usr/bin:\n"
            "  brew install universal-ctags\n"
            "  which -a ctags"
        )


def _ctags_cmd(paths: Iterable[str], *, languages: str, excludes: list[str]) -> list[str]:
    cmd = [
        "ctags",
        "-R",
        "--output-format=json",
        "--fields=+n+e+S+Z",
        "--sort=no",
        "--quiet=yes",
        f"--languages={languages}",
    ]
    for ex in DEFAULT_EXCLUDES:
        cmd.append(f"--exclude={ex}")
    for ex in excludes:
        cmd.append(f"--exclude={ex}")
    cmd.extend(paths)
    return cmd


def _norm_kind(kind: str) -> str:
    if kind in {"member", "method"}:
        return "method"
    return kind


def main(argv: Optional[list[str]] = None) -> int:
    args = _parse_args(argv)
    _require_universal_ctags()

    include_kinds = {k.strip() for k in args.include_kinds.split(",") if k.strip()}
    languages = ",".join([s.strip() for s in args.languages.split(",") if s.strip()])

    cmd = _ctags_cmd(args.paths, languages=languages, excludes=args.exclude)
    proc = subprocess.run(cmd, text=True, capture_output=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        return proc.returncode

    symbols: list[dict[str, Any]] = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            tag = json.loads(line)
        except json.JSONDecodeError:
            continue

        if tag.get("_type") != "tag":
            continue

        kind = tag.get("kind")
        if not isinstance(kind, str):
            continue
        if kind not in include_kinds:
            continue

        path = tag.get("path")
        name = tag.get("name")
        line_no = tag.get("line")
        end_no = tag.get("end")
        if not (isinstance(path, str) and isinstance(name, str) and isinstance(line_no, int)):
            continue

        sym: dict[str, Any] = {
            "path": path,
            "kind": _norm_kind(kind),
            "name": name,
            "start_line": line_no,
            "end_line": end_no if isinstance(end_no, int) else line_no,
        }

        if isinstance(tag.get("scope"), str):
            sym["scope"] = tag["scope"]
        if isinstance(tag.get("scopeKind"), str):
            sym["scope_kind"] = tag["scopeKind"]
        if isinstance(tag.get("signature"), str):
            sym["signature"] = tag["signature"]

        symbols.append(sym)

    symbols.sort(key=lambda s: (s["path"], s["start_line"], s["kind"], s["name"]))

    if args.format == "json":
        print(json.dumps(symbols, indent=2, sort_keys=True))
        return 0

    for s in symbols:
        qn = s["name"]
        if "scope" in s:
            qn = f"{s['scope']}.{qn}"
        sig = s.get("signature", "")
        print(f"{s['path']}:{s['start_line']}-{s['end_line']} {s['kind']} {qn}{sig}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
