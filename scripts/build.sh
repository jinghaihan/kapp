#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

swift build
binary_dir="$(swift build --show-bin-path)"
app_dir="$PWD/.build/Kapp.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Kapp" "$app_dir/Contents/MacOS/Kapp"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp LICENSE THIRD_PARTY_NOTICES.md "$app_dir/Contents/Resources/"
codesign --force --sign - "$app_dir"
printf '%s\n' "$app_dir"
