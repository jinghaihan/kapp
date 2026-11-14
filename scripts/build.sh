#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    selected_developer_dir="$(xcode-select -p)"
    if [[ "$selected_developer_dir" == *.app/Contents/Developer ]]; then
        export DEVELOPER_DIR="$selected_developer_dir"
    elif [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
        export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    fi
fi

swift build "$@"
binary_dir="$(swift build "$@" --show-bin-path)"
app_dir="$PWD/.build/Kapp.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Kapp" "$app_dir/Contents/MacOS/Kapp.next"
mv -f "$app_dir/Contents/MacOS/Kapp.next" "$app_dir/Contents/MacOS/Kapp"
cp resources/Info.plist "$app_dir/Contents/Info.plist"
cp resources/AppIcon.icns "$app_dir/Contents/Resources/"
cp LICENSE THIRD_PARTY_NOTICES.md "$app_dir/Contents/Resources/"
cp -R "$binary_dir/Kapp_Kapp.bundle" "$app_dir/Contents/Resources/"
cp -R "$binary_dir/Kapp_KappLocalization.bundle" "$app_dir/Contents/Resources/"
for language_dir in "$binary_dir/Kapp_KappLocalization.bundle/"*.lproj; do
    language="$(basename "$language_dir")"
    case "$language" in
        zh-hans.lproj) language=zh-Hans.lproj ;;
        zh-hant.lproj) language=zh-Hant.lproj ;;
    esac
    app_language_dir="$app_dir/Contents/Resources/$language"
    mkdir -p "$app_language_dir"
    cp "$language_dir/InfoPlist.strings" "$app_language_dir/"
done
cp -R third-party-licenses "$app_dir/Contents/Resources/"
python3 scripts/sign.py "$app_dir"
printf '%s\n' "$app_dir"
