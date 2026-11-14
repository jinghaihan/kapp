# Releasing

Versioning follows the repository's English Conventional Commit history. Release notes are generated with changelogithub.

## Version upgrade

Preview a version upgrade without changing files, creating a tag, or pushing:

```sh
python3 scripts/release.py minor --dry-run
```

When ready to publish, run from a clean `main` branch synchronized with `origin/main`:

```sh
python3 scripts/release.py minor
```

Use `patch`, `minor`, or `major` as appropriate. The script updates the app version, creates a Conventional Commit and an annotated tag, then pushes `main` and the tag atomically.

## GitHub Actions

- **Build:** Pushes to `main` and pull requests run Swift and Python tests, build the macOS app, and upload a ZIP as a workflow artifact.
- **Release:** Pushing a `v*` tag verifies the version, runs tests, and builds a universal app for Apple Silicon and Intel. It packages a DMG and ZIP, generates release notes with changelogithub, verifies SHA-256 checksums, and publishes the downloads on GitHub Releases.

The workflows use the current repository name rather than a hard-coded upstream. CI packages are ad-hoc signed. Developer ID signing and notarization are not configured, and the local development certificate and private key are never uploaded to CI.

## Automatic updates

Sparkle reads `appcast.xml` from the latest GitHub release. The release workflow
signs the ZIP using the repository's `SPARKLE_PRIVATE_KEY` Actions secret and
uploads the feed with the downloads before publishing the release. The public
key is embedded as `SUPublicEDKey` in `resources/Info.plist`. A missing signing
secret stops the release rather than publishing an unusable update feed.

Keep the matching private key backed up outside the repository. It is separate
from the local development code-signing certificate. For this repository it is
stored in the macOS login Keychain under Sparkle's `app.kapp.recorder` account;
use Sparkle's `generate_keys --account app.kapp.recorder -x <private-file>` to
export it and `gh secret set SPARKLE_PRIVATE_KEY < <private-file>` to configure
CI. Delete the exported file afterwards. Never commit private keys.

To generate the feed locally after packaging, set `SPARKLE_PRIVATE_KEY` securely
in your environment and run `python3 scripts/appcast.py`. The script embeds the
changelogithub notes and uses the Sparkle tools from the resolved Swift package.
Only user-initiated update checks are enabled. Downloaded archives are verified
against the embedded public key before extraction. Updating follows the normal
quit workflow, including confirmation before discarding an open recording.

## Local packaging

```sh
bash scripts/build.sh --configuration release --arch arm64 --arch x86_64
python3 scripts/package.py
```

The DMG, ZIP, and `SHA256SUMS` are written to `dist/`. Packaging alone does not create a tag or publish a release.
