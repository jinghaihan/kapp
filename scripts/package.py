#!/usr/bin/env python3
"""Package a universal macOS app without publishing anything."""
import argparse
import hashlib
import plistlib
import subprocess
import tempfile
from pathlib import Path

from release import ROOT, read_version


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path, default=ROOT / ".build/Kapp.app")
    parser.add_argument("--tag")
    args = parser.parse_args()
    version = read_version()
    if args.tag and args.tag != "v" + version:
        raise SystemExit("Release tag and Info.plist version do not match.")
    app = args.app.resolve()
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info["CFBundleShortVersionString"] != version:
        raise SystemExit("Rebuild the app after changing its version.")
    subprocess.run(["codesign", "--verify", "--strict", str(app)], check=True)
    architectures = subprocess.check_output(["lipo", "-archs", str(app / "Contents/MacOS/Kapp")], text=True).split()
    if set(architectures) != {"arm64", "x86_64"}:
        raise SystemExit("Build both arm64 and x86_64 before packaging.")
    output = ROOT / "dist"
    output.mkdir(exist_ok=True)
    stem = f"Kapp-{version}-macos-universal"
    archive = output / (stem + ".zip")
    subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(app), str(archive)], check=True)
    image = output / (stem + ".dmg")
    with tempfile.TemporaryDirectory() as directory:
        folder = Path(directory)
        subprocess.run(["ditto", str(app), str(folder / "Kapp.app")], check=True)
        (folder / "Applications").symlink_to("/Applications")
        subprocess.run(["hdiutil", "create", "-quiet", "-ov", "-volname", "Kapp", "-format", "UDZO",
                        "-srcfolder", str(folder), str(image)], check=True)
    (output / "SHA256SUMS").write_text("".join(
        f"{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}\n" for file in [archive, image]
    ))
    print(output)


if __name__ == "__main__":
    main()
