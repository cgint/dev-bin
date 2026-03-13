#!/usr/bin/env python3
"""Normalize OpenSpec slash-command aliases in skill docs.

By default, this rewrites OpenSpec skills under definitions/skills:
  /opsx:apply   -> /skill:openspec-apply-change
  /opsx:explore -> /skill:openspec-explore
  /opsx:propose -> /skill:openspec-propose
  /opsx:archive -> /skill:openspec-archive-change

Usage:
  ./normalize_openspec_skill_aliases.py
  ./normalize_openspec_skill_aliases.py --apply
  ./normalize_openspec_skill_aliases.py --source-root generated --glob "**/skills/openspec-*/SKILL.md" --apply
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent

DEFAULT_REPLACEMENTS: tuple[tuple[str, str], ...] = (
    ("/opsx:apply", "/skill:openspec-apply-change"),
    ("/opsx:explore", "/skill:openspec-explore"),
    ("/opsx:propose", "/skill:openspec-propose"),
    ("/opsx:archive", "/skill:openspec-archive-change"),
)


def ensure_within_repo(path: Path) -> bool:
    try:
        repo = REPO_ROOT.resolve()
        p = path.resolve()
        return os.path.commonpath([str(repo), str(p)]) == str(repo)
    except Exception:
        return False


def normalize_text(text: str, replacements: tuple[tuple[str, str], ...]) -> tuple[str, bool]:
    out = text
    for old, new in replacements:
        out = out.replace(old, new)
    return out, out != text


def discover_targets(source_root: Path, glob_pattern: str) -> list[Path]:
    if not source_root.exists():
        return []
    return sorted([p for p in source_root.glob(glob_pattern) if p.is_file()])


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source-root",
        default="definitions/skills",
        help="Directory (inside repo) to scan for files.",
    )
    parser.add_argument(
        "--glob",
        default="openspec-*/SKILL.md",
        help="Glob pattern relative to source-root.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write changes. Default is dry-run.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit with code 1 if any file would change.",
    )
    args = parser.parse_args(argv)

    source_root = (REPO_ROOT / args.source_root).resolve()
    if not ensure_within_repo(source_root):
        print(f"ERROR: source-root must be inside repo root: {REPO_ROOT}")
        return 2

    targets = discover_targets(source_root, args.glob)
    if not targets:
        print(f"No files matched: {source_root.relative_to(REPO_ROOT)}/{args.glob}")
        return 0

    changed_files = []
    for path in targets:
        original = path.read_text(encoding="utf-8")
        normalized, changed = normalize_text(original, DEFAULT_REPLACEMENTS)
        if not changed:
            continue

        changed_files.append(path)
        rel = path.relative_to(REPO_ROOT)
        if args.apply:
            path.write_text(normalized, encoding="utf-8")
            print(f"updated {rel}")
        else:
            print(f"would update {rel}")

    print(
        f"\nScanned {len(targets)} files; "
        f"{len(changed_files)} {'file' if len(changed_files) == 1 else 'files'} "
        f"{'updated' if args.apply else 'would change'}."
    )

    if args.check and changed_files:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
