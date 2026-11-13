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

Local builds reuse a private Kapp development certificate under
`~/Library/Application Support/Kapp/Development`, keeping their signing identity
stable across rebuilds. On first setup, approve this certificate for code signing:

```sh
python3 scripts/sign.py .build/Kapp.app --trust
bash scripts/build.sh
```

The certificate is trusted only for code signing. Its private key and keychain
password stay outside the repository. An Apple-issued identity can be supplied
with `KAPP_SIGNING_IDENTITY`. CI uses `KAPP_SIGNING_IDENTITY=-` for ad-hoc packages.
Switching from an old ad-hoc build requires granting screen recording access once
more and reopening Kapp. Subsequent local builds reuse the same certificate.

Click the menu bar icon, draw an area, adjust it and click the red record button.
The crop icon opens dimensions; the window and fullscreen icons change the source.
Microphone, system audio and cursor options are in the action bar's More menu. Click the
menu bar icon again to stop. Right-click it for screen/window capture, pause and
audio options. ⌘⇧5 starts area selection or stops the current recording globally.
Escape cancels selection. Recordings are saved under `~/Movies/Kapp`.

Stopping opens the editor. Drag either white endpoint on the playback track to
trim; the selected range applies immediately. Choose MP4 or GIF and Save to Disk
or Copy to Clipboard, then click Convert. The speaker button mutes MP4 exports.
Open an existing recording with ⌘O or the menu bar's Open Recording item.
GIFs loop at 15 fps, with a maximum dimension of 960 pixels. Copy provides the
exported file and, for GIFs, animated image data to compatible apps.
The original recording is kept. Cancelling an export leaves existing files intact.

## Structure

```text
sources/
  app/                  App entry, recording workflow and native controls
    selection/          Area drawing, resize/move, system picker and border
    editor/             Native video player and trimming window
    export/             MP4/GIF processing and clipboard representations
  recording/            ScreenCaptureKit streams, audio and MP4 writing
tests/
  Apptests/             Selection coordinate conversion
  Recordingtests/       Display sizing and encoded recording regression tests
resources/              App metadata and permission descriptions
scripts/                Local app build
```

`KappRecording` is a separate Swift package target. It takes a content filter,
capture options and output URL; it does not depend on the app or its selection UI.
Recording uses H.264/AAC in MP4. No third-party dependencies are required.

## Tests

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```
