#!/usr/bin/env python3
"""Check the Git index for common secrets/private state before publishing.

This deliberately small, offline check is not a security audit or an exhaustive
secret detector. It prints rules and line numbers, never the matched content.
Run it after `git add`; it checks staged blobs, not untracked local data.
"""

from __future__ import annotations

import re
import subprocess
from pathlib import PurePosixPath


RULES = {
    "API credential": re.compile(r"\bsk-[A-Za-z0-9_-]{20,}"),
    "GitHub credential": re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})"),
    "private key": re.compile(r"-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----"),
    "tunnel identifier": re.compile(r"\btunnel_[a-zA-Z0-9]{24,}"),
    "organization identifier": re.compile(r"\borg-[a-zA-Z0-9]{16,}"),
    "personal Windows path": re.compile(r"[A-Za-z]:[\\/]Users[\\/](?![<{$%]|Public\b)[A-Za-z0-9._-]+"),
    "personal Linux path": re.compile(r"/home/(?![<{$%])[A-Za-z0-9._-]+/"),
    "private conversation link": re.compile(r"https://(?:chatgpt\.com|chat\.openai\.com)/c/[a-zA-Z0-9-]+"),
    "email address": re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"),
}
ALLOWED_ROOT_FILES = {".gitignore", ".gitattributes", "LICENSE"}
ALLOWED_SUFFIXES = {".py", ".ps1", ".cmd", ".sh", ".md", ".yml"}
PRIVATE_PARTS = {".env", ".local", "state", "private", "workspace", "exports", ".venv", "node_modules"}


def check_content(name: str, data: bytes) -> list[str]:
    findings = []
    path = PurePosixPath(name)
    if any(part in PRIVATE_PARTS or part.startswith(".env.") for part in path.parts):
        findings.append("private-state path")
    if name not in ALLOWED_ROOT_FILES and path.suffix not in ALLOWED_SUFFIXES:
        findings.append("unreviewed file type")
    if len(data) > 1_000_000:
        return findings + ["unexpectedly large source file"]
    try:
        source = data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return findings + ["non-UTF-8 content"]
    if "\x00" in source:
        findings.append("binary content")
    for number, line in enumerate(source.splitlines(), 1):
        for rule, pattern in RULES.items():
            if pattern.search(line):
                findings.append(f"line {number}: {rule}")
    return findings


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", *args], stderr=subprocess.DEVNULL)


def main() -> int:
    try:
        entries = git("ls-files", "--stage", "-z").split(b"\0")
        count = 0
        bad = False
        for entry in filter(None, entries):
            metadata, raw_name = entry.split(b"\t", 1)
            mode, object_id, stage = metadata.split()
            name = raw_name.decode("utf-8")
            findings = []
            if mode not in (b"100644", b"100755") or stage != b"0":
                findings.append("symlink, submodule, or unresolved merge")
            else:
                findings += check_content(name, git("cat-file", "blob", object_id.decode("ascii")))
            count += 1
            for finding in findings:
                print(f"{name}: {finding}")
                bad = True
        if count == 0:
            print("No staged/tracked source files found. Stage reviewed source first.")
            return 1
        print(f"PUBLIC_SOURCE_CHECK={'FAIL' if bad else 'PASS'} ({count} indexed files)")
        return int(bad)
    except (OSError, subprocess.CalledProcessError, ValueError, UnicodeError):
        print("Source check failed: run from a Git repository with a readable index.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
