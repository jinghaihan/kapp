<p align="center">
  <img src="design/AppIcon.png" alt="Kapp logo" width="160" height="160">
</p>

<h1 align="center">Kapp</h1>

<p align="center">Capture your screen. Trim it. Share it.</p>

> [!NOTE]
> Kapp's UI design and interaction model are based entirely on [Kap](https://getkap.co/), reimplemented with native macOS components. Recording, audio, and parts of area selection use source code adapted from [BetterCapture](https://github.com/jsattler/BetterCapture). Both projects' original copyright and license notices are retained.

A native macOS screen recorder with area, window, and full-screen capture, a simple trimming editor, and MP4 or GIF export.

![Kapp's editor and capture toolbar on a desert desktop, showing mountain footage, trim handles, and export controls](docs/images/preview.jpg)

## Features

- **Capture:** Draw an area, choose a window, or record a whole display. Adjust dimensions and aspect ratio before starting.
- **Audio:** Record system audio, your microphone, or both. Include or hide the mouse cursor.
- **Controls:** Start or stop with a configurable shortcut, initially `⌘⇧5`. Option-click the recording menu bar icon to pause; click it while paused to resume.
- **Trim:** Preview your recording and drag either endpoint to keep the part you need. Hover over the timeline to preview frames.
- **Export:** Choose MP4 or GIF, adjust dimensions and frame rate, and follow conversion progress. Save to disk or copy to the clipboard.
- **Languages:** English, Simplified Chinese, Traditional Chinese, Japanese, and Korean. Choose a language in Preferences or follow macOS, with English as the fallback.

## Get started

Requires macOS 15.2 or later. Download the DMG from the [latest release](https://github.com/jinghaihan/kapp/releases/latest), open it, and drag Kapp to Applications. The download supports both Apple Silicon and Intel Macs.

See the [development guide](docs/development.md) to build from source with Xcode or use a persistent local signing identity. Release downloads are ad-hoc signed and are not notarized.

Launch Kapp, then click its menu bar icon or press `⌘⇧5` to select an area. The window and full-screen buttons change what is recorded; click the red button to start. Click the menu bar icon again to stop and open the editor. Press `Escape` to cancel selection.

In the editor, drag the two timeline handles to trim, choose an output format and destination, then click **Convert**. Original recordings are kept in `~/Movies/Kapp` while editing and deleted when their editor closes, with a final cleanup when Kapp quits. Exported files and videos opened with **Open Video…** or `⌘O` are kept.

Open **Preferences…** from the menu bar's context menu, the capture toolbar's More menu, or `⌘,`. Set the recording shortcut, cursor visibility, click highlighting, microphone and input device, system audio, capture frame rate, and launch at login. Preferences are saved automatically; capture changes apply to the next recording. The default export folder starts on Desktop. Choose another folder in Preferences to change it; saving an individual export elsewhere leaves that default unchanged.

Choose **Check for Updates…** from the menu to check GitHub Releases. Confirm an update to download, install, and relaunch Kapp without opening a browser or installer.

## Development

See [Development](docs/development.md) for build instructions and tests, and [Releasing](docs/releasing.md) for version upgrades, GitHub Actions, and release packaging.

## Credits

- [Kap](https://github.com/wulkano/Kap) by [Wulkano](https://wulkano.com): the UI design and interaction model, capture and playback icons, and adapted conversion test cases.
- [BetterCapture](https://github.com/jsattler/BetterCapture) by [Joshua Sattler](https://github.com/jsattler) and contributors: selected recording, audio timing, display sizing, area selection, and selection-border implementations.

See [Third-party notices](THIRD_PARTY_NOTICES.md) for source revisions and retained licenses. Kapp is an independent project and is not affiliated with either upstream project.

## License

[MIT](./LICENSE) License © [jinghaihan](https://github.com/jinghaihan) for original contributions. Adapted code and assets retain their original copyright and MIT license notices.
