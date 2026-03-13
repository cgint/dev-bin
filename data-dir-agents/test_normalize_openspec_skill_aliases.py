#!/usr/bin/env python3
"""Tests for normalize_openspec_skill_aliases.py."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from normalize_openspec_skill_aliases import (
    DEFAULT_REPLACEMENTS,
    normalize_text,
)


def test_replaces_opsx_aliases_with_skill_aliases():
    source = (
        "When ready, run /opsx:apply.\n"
        "If needed, use /opsx:explore first.\n"
        "Then do /opsx:archive.\n"
    )
    out, changed = normalize_text(source, DEFAULT_REPLACEMENTS)

    assert changed is True
    assert "/opsx:apply" not in out
    assert "/opsx:explore" not in out
    assert "/opsx:archive" not in out
    assert "/skill:openspec-apply-change" in out
    assert "/skill:openspec-explore" in out
    assert "/skill:openspec-archive-change" in out


def test_returns_unchanged_when_no_opsx_alias_present():
    source = "No slash command aliases here.\n"
    out, changed = normalize_text(source, DEFAULT_REPLACEMENTS)
    assert out == source
    assert changed is False


def test_handles_multiple_occurrences():
    source = "Use /opsx:apply then /opsx:apply again.\n"
    out, changed = normalize_text(source, DEFAULT_REPLACEMENTS)
    assert changed is True
    assert out.count("/skill:openspec-apply-change") == 2
    assert "/opsx:apply" not in out
