# Development

Requires macOS 15.2 or later and Xcode 26 or later, including the macOS SDK.

## Build and run

```sh
git clone https://github.com/jinghaihan/kapp.git
cd kapp
bash scripts/build.sh
open .build/Kapp.app
```

The build script respects `DEVELOPER_DIR` or the full Xcode selected with `xcode-select`. If only Command Line Tools are selected, it falls back to `/Applications/Xcode.app/Contents/Developer`. It builds a native app at `.build/Kapp.app`.

## Local signing

Local builds reuse a private Kapp development certificate under `~/Library/Application Support/Kapp/Development`, keeping the signing identity stable across rebuilds. The private key and keychain password stay outside the repository.

The first build creates the identity. If signing stops because the certificate is not yet trusted, explicitly trust it for code signing, then rebuild:

```sh
python3 scripts/sign.py .build/Kapp.app --trust
bash scripts/build.sh
```

This trusts only the Kapp code-signing certificate for the current user. An Apple-issued signing identity can be supplied with `KAPP_SIGNING_IDENTITY` instead. CI uses `KAPP_SIGNING_IDENTITY=-` for ad-hoc development packages.

Grant Kapp screen recording access in **System Settings → Privacy & Security → Screen & System Audio Recording**. Microphone access is requested when microphone recording is enabled. Switching from an old ad-hoc build to the persistent development identity requires refreshing the screen recording grant once. Keep using the same signed app and installation path for subsequent builds.

## Tests

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
python3 -m unittest discover -s scripts -p 'test_*.py'
```

The conversion tests adapt Kap's MP4/GIF expectations to generated local video fixtures. They cover trim ranges, output dimensions, frame rate, audio, and cancellation without downloading media or using private recordings. Native window tests cover close confirmation, preview cleanup, and focus-dependent playback.

## Structure

```text
sources/
  app/                  App entry and recording workflow
    assets/             Retained Kap SVG icons
    components/         Shared native components
    selection/          Area selection, window menu, toolbar, and border
    editor/             Preview, trimming, and export controls
  recording/            ScreenCaptureKit streams, audio, and MP4 writing
tests/
  app-tests/            Selection, editor, and export regression tests
  recording-tests/      Recording and display-sizing regression tests
resources/              App metadata and application icon
design/                 Original application icon artwork
docs/                   Guides and native UI previews
scripts/                Build, signing, versioning, and packaging tools
third-party-licenses/   Retained third-party license notices
```

`KappRecording` is a separate Swift package target. It accepts a content filter, capture options, and an output URL without depending on the app or selection UI. Recordings use H.264/AAC in MP4. No third-party runtime dependencies are required.

## Branding

`design/AppIcon-concept.png` retains the original concept artwork. `design/AppIcon.png` is the transparent production source. Regenerate the packaged icon with:

```sh
swift scripts/build-icon.swift
```

The menu bar uses system symbols rather than bundled PNG animation frames.
