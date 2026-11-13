# Kapp

A local macOS recorder prototype built from selected
[BetterCapture](https://github.com/jsattler/BetterCapture) source files.
Credit to Joshua Sattler and the BetterCapture contributors;
see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and [LICENSE](LICENSE).

Requires macOS 15.2+ and Xcode 26+.

## Run locally

```sh
bash scripts/build.sh
open .build/Kapp.app
```

Select an area, screen or window, then start recording. Stop from the menu bar
or with ⌘. while Kapp is focused. Recordings are saved under `~/Movies/Kapp`.
System audio, microphone, cursor visibility and pause/resume are supported.

The current window only validates the recording core. Post-recording preview,
trimming and GIF export are not implemented yet.

## Structure

```text
Sources/
  App/                  App entry, recording workflow and native controls
    Selection/          Area drawing, resize/move, system picker and border
  Recording/            ScreenCaptureKit streams, audio and MP4 writing
Tests/
  AppTests/             Selection coordinate conversion
  RecordingTests/       Display sizing and encoded recording regression tests
Resources/              App metadata and permission descriptions
scripts/                Local app build
```

`KappRecording` is a separate Swift package target. It takes a content filter,
capture options and output URL; it does not depend on the app or its selection UI.
Recording uses H.264/AAC in MP4. No third-party dependencies are required.

## Tests

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
