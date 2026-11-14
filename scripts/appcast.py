#!/usr/bin/env python3
"""Generate the signed Sparkle feed attached to each GitHub release."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

from release import ROOT, read_version


def generate_feed(archive, notes, tool, repository, key):
    version = read_version()
    download_prefix = f"https://github.com/{repository}/releases/download/v{version}/"
    with tempfile.TemporaryDirectory() as temporary:
        folder = Path(temporary)
        shutil.copyfile(archive, folder / archive.name)
        if notes:
            shutil.copyfile(notes, folder / (archive.stem + ".md"))
        subprocess.run([
            str(tool), "--ed-key-file", "-", "--download-url-prefix", download_prefix,
            "--embed-release-notes", "--maximum-deltas", "0", str(folder),
        ], input=key, text=True, check=True)
        feed = folder / "appcast.xml"
        root = ET.parse(feed).getroot()
        item = root.find("channel/item")
        sparkle = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
        if item is None or item.findtext(sparkle + "version") != version:
            raise ValueError("The update feed does not match the app version.")
        enclosure = item.find("enclosure")
        if (enclosure is None or not enclosure.get(sparkle + "edSignature")
                or enclosure.get("url") != download_prefix + archive.name
                or int(enclosure.get("length", "0")) != archive.stat().st_size):
            raise ValueError("The update feed is missing a signed release archive.")
        return feed.read_bytes()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", "jinghaihan/kapp"))
    parser.add_argument("--tool", type=Path, default=ROOT / ".build/artifacts/sparkle/Sparkle/bin/generate_appcast")
    args = parser.parse_args()
    key = os.environ.get("SPARKLE_PRIVATE_KEY")
    if not key:
        raise SystemExit("SPARKLE_PRIVATE_KEY must be configured before publishing updates.")
    archive = ROOT / "dist" / f"Kapp-{read_version()}-macos-universal.zip"
    notes = ROOT / "dist/release-notes.md"
    feed = generate_feed(archive, notes, args.tool, args.repository, key)
    (ROOT / "dist/appcast.xml").write_bytes(feed)


if __name__ == "__main__":
    main()
