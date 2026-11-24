#!/usr/bin/env -S uv run --no-project --python >=3.10
"""Merge Pi session history from ~/.pi/agent and ~/.pi/profiles/*/agent into a new staging directory."""

import argparse
from collections import Counter
from dataclasses import dataclass
from itertools import zip_longest
import json
import os
from pathlib import Path
import shutil
import stat


@dataclass(frozen=True)
class Entry:
    path: Path
    relative: Path
    root: Path
    metadata: tuple[int, ...]
    session_id: str | None
    parent: str | None


def signature(info):
    return (info.st_dev, info.st_ino, info.st_size, info.st_mode, info.st_mtime_ns, info.st_ctime_ns)


def inventory(roots):
    entries = []
    for root in roots:
        if not root.exists():
            continue
        if root.is_symlink():
            raise ValueError("A session root is a symlink")
        for path in sorted(root.rglob("*")):
            info = path.lstat()
            if stat.S_ISDIR(info.st_mode):
                continue
            if not stat.S_ISREG(info.st_mode):
                raise ValueError("A session tree contains a non-regular file")
            session_id = None
            parent = None
            if path.suffix == ".jsonl":
                with path.open("rb") as source:
                    try:
                        header = json.loads(source.readline())
                    except (ValueError, UnicodeDecodeError) as exc:
                        raise ValueError(f"Invalid or empty JSONL header: {path.relative_to(root)}") from exc
                    if not isinstance(header, dict):
                        raise ValueError(f"Invalid JSONL header object: {path.relative_to(root)}")
                    if signature(os.fstat(source.fileno())) != signature(info):
                        raise ValueError("A source file changed during inventory; retry when Pi is stopped")
                if header.get("type") == "session":
                    session_id = header.get("id")
                    parent = header.get("parentSession")
                    if not isinstance(session_id, str) or (parent is not None and not isinstance(parent, str)):
                        raise ValueError("Invalid Pi session header")
            entries.append(Entry(path, path.relative_to(root), root, signature(info), session_id, parent))
    return entries


def rewrite_header(header, parent):
    data = json.loads(header)
    data["parentSession"] = parent
    newline = b"\r\n" if header.endswith(b"\r\n") else b"\n"
    return json.dumps(data, ensure_ascii=False, separators=(",", ":")).encode() + newline


def chunks(stream):
    return iter(lambda: stream.read(1024 * 1024), b"")


def merge_history(roots, output, final_root, profiles_root):
    if output.exists() or output.is_symlink():
        raise ValueError("Choose a new output directory")
    canonical_output = output.resolve()
    if any(canonical_output.is_relative_to(root) or root.is_relative_to(canonical_output) for root in roots):
        raise ValueError("Staging must be separate from the source session trees")

    entries = inventory(roots)
    destinations = {}
    session_ids = set()
    for entry in entries:
        folded = str(entry.relative).casefold()
        if folded in destinations:
            raise ValueError("A relative session file path would be overwritten")
        destinations[folded] = entry
        if entry.session_id is not None:
            if entry.session_id in session_ids:
                raise ValueError("A Pi session ID occurs more than once")
            session_ids.add(entry.session_id)
    for entry in entries:
        if any(str(folder).casefold() in destinations for folder in entry.relative.parents):
            raise ValueError("A file would hide a session directory")

    final_paths = {
        os.path.realpath(entry.path): str(final_root / entry.relative)
        for entry in entries if entry.session_id is not None
    }
    remapped = 0
    output.mkdir(parents=True, mode=0o700)
    for entry in entries:
        dest = output / entry.relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        parent = final_paths.get(os.path.realpath(entry.parent)) if entry.parent else None
        new_parent = parent if parent != entry.parent else None
        with entry.path.open("rb") as source, dest.open("xb") as target:
            if signature(os.fstat(source.fileno())) != entry.metadata:
                raise ValueError("A source file changed before copying")
            if new_parent:
                target.write(rewrite_header(source.readline(), new_parent))
                remapped += 1
            shutil.copyfileobj(source, target)
        shutil.copystat(entry.path, dest)
        if dest.stat().st_mtime_ns != entry.metadata[4]:
            raise ValueError("A destination timestamp differs")
        with entry.path.open("rb") as source, dest.open("rb") as target:
            if new_parent:
                if target.readline() != rewrite_header(source.readline(), new_parent):
                    raise ValueError("A migrated fork header differs")
            if any(a != b for a, b in zip_longest(chunks(source), chunks(target))):
                raise ValueError("A destination payload differs")
            if signature(os.fstat(source.fileno())) != entry.metadata:
                raise ValueError("A source file changed while being copied")

    for entry in entries:
        if entry.session_id is None:
            continue
        with (output / entry.relative).open("rb") as staged:
            staged_header = json.loads(staged.readline())
        parent = staged_header.get("parentSession")
        if parent and Path(os.path.realpath(parent)).is_relative_to(profiles_root):
            raise ValueError(f"Unresolved profile parentSession: {entry.relative}")

    if entries != inventory(roots):
        raise ValueError("The source inventory changed; make a new stage after all writers have stopped")
    counts = Counter("default" if entry.root == roots[0] else entry.root.parent.parent.name
                     for entry in entries if entry.session_id is not None)
    return {
        "files": len(entries),
        "sessions": len(session_ids),
        "sessions_by_source": dict(counts),
        "remapped": remapped,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pi_home", type=Path)
    parser.add_argument("staged_sessions", type=Path)
    args = parser.parse_args()
    pi_home = args.pi_home.resolve()
    dest = args.staged_sessions.absolute()
    if dest.resolve().is_relative_to(pi_home):
        parser.error("staging must be outside the active Pi home")
    default = pi_home / "agent" / "sessions"
    roots = [default]
    profiles = pi_home / "profiles"
    if profiles.is_dir():
        for profile in sorted(profiles.iterdir()):
            if profile.is_symlink() or (profile / "agent").is_symlink():
                parser.error("profile directories must not be symlinks")
            if profile.is_dir():
                roots.append(profile / "agent" / "sessions")
    print(json.dumps(merge_history(roots, dest, default, profiles), sort_keys=True))


if __name__ == "__main__":
    main()
