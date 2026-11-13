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

## Local packaging

```sh
bash scripts/build.sh --configuration release --arch arm64 --arch x86_64
python3 scripts/package.py
```

The DMG, ZIP, and `SHA256SUMS` are written to `dist/`. Packaging alone does not create a tag or publish a release.
