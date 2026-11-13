#!/usr/bin/env python3
"""Bump, commit and push a release tag, matching the other local Swift projects."""
import argparse
import plistlib
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INFO = ROOT / "resources/Info.plist"


def read_version():
    return plistlib.loads(INFO.read_bytes())["CFBundleShortVersionString"]


def bump_version(current, bump):
    if not re.fullmatch(r"\d+\.\d+\.\d+", current):
        raise ValueError("Expected a stable major.minor.patch version")
    major, minor, patch = map(int, current.split("."))
    return {"major": f"{major + 1}.0.0", "minor": f"{major}.{minor + 1}.0", "patch": f"{major}.{minor}.{patch + 1}"}[bump]


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("bump", choices=["patch", "minor", "major"])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    current = read_version()
    version = bump_version(current, args.bump)
    tag = "v" + version
    print(f"v{current} → {tag}", flush=True)
    if args.dry_run:
        return
    if git("branch", "--show-current") != "main" or git("status", "--porcelain"):
        raise SystemExit("Release from a clean main branch.")
    git("fetch", "origin", "main", "--tags")
    if git("rev-parse", "HEAD") != git("rev-parse", "origin/main"):
        raise SystemExit("Synchronize main with origin/main before releasing.")
    if git("tag", "--list", tag):
        raise SystemExit("The release tag already exists.")
    info = plistlib.loads(INFO.read_bytes())
    info["CFBundleShortVersionString"] = version
    info["CFBundleVersion"] = version
    INFO.write_bytes(plistlib.dumps(info, sort_keys=False))
    git("add", str(INFO.relative_to(ROOT)))
    git("commit", "-m", f"chore: release {tag}")
    git("tag", "-a", tag, "-m", tag)
    git("push", "--atomic", "origin", "main", tag)


if __name__ == "__main__":
    main()
