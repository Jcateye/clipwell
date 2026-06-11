# Clipwell

Clipwell is a local-first clipboard drawer for macOS by Mio Miao Labs LLC. / 深圳市弥傲科技有限责任公司.

It runs as a menu bar app, keeps recent clipboard items on the Mac, and lets you open a side drawer to search, preview, and restore previous clips.

## Features

- Local clipboard history for macOS
- Menu bar app with global shortcut support
- Side drawer with search, type filters, and keyboard navigation
- Text, rich text, HTML, image, media, and document/file URL handling
- Preview pane for supported clipboard content
- Optional auto-paste and auto-close behavior
- Pro actions: image OCR, screenshot OCR, and translation with macOS Translation by default or an OpenAI-compatible endpoint when configured
- Local vocabulary window with search and delete
- Pause monitoring, clear history, history limit, and ignored apps
- SQLite-backed local storage with payload files

## Requirements

- macOS 15 or later
- Xcode / Swift toolchain with Swift 6 support

## Development

Build:

```sh
swift build
```

Run tests:

```sh
swift test
```

Run locally:

```sh
swift run ClipboardDrawer
```

Package a local `.app` bundle and zip:

```sh
scripts/package_app.sh release
```

This writes:

- `.build/app/Clipwell.app`
- `dist/Clipwell-macOS.zip`

Package a DMG for website distribution:

```sh
scripts/package_dmg.sh release
```

This writes `dist/Clipwell.dmg`.

Prepare the website download file before deploying the static site:

```sh
scripts/prepare_website_download.sh release
```

This writes `marketing/clipwell/downloads/Clipwell-latest.dmg`, which is the file used by the website download buttons. It also keeps `marketing/clipwell/downloads/Clipwell-latest.zip` as a backup artifact.

The current Swift Package executable target is still named `ClipboardDrawer`. User-facing App Store branding is `Clipwell`.

## Windows version

A native Windows client (.NET 8 + WPF) lives in `windows/Clipwell.Win/` and evolves
independently of the macOS app while mirroring its data structures (same SQLite schema
and payload layout). See `windows/Clipwell.Win/README.md` for build instructions; CI
builds it on `windows-latest` via `.github/workflows/windows-build.yml`.

## App Store Preparation

The App Store launch plan and marketing website are included in:

- `docs/app-store-launch-plan.md`
- `docs/clipwell-website-operations.md`
- `marketing/clipwell/`

Production website:

- Primary URL: `https://clipwell.mioerlab.com/`
- Cloudflare Pages fallback: `https://clipwell-site.pages.dev/`
- Privacy URL: `https://clipwell.mioerlab.com/privacy`
- Support URL: `https://clipwell.mioerlab.com/support`

## Plugin Pipeline

Clipwell is evolving toward a local-first plugin pipeline where copied content can be processed by ordered plugins. The design and authoring contract are documented in:

- `docs/plugin-pipeline-design.md`
- `docs/plugin-authoring-v1.md`

The planned bundle identifier is:

```text
com.miomiaolabs.clipwell
```

## Privacy

Clipwell is designed to store clipboard history locally on the user's Mac. The planned public release does not require an account or upload clipboard history to a server.

## License

MIT License. See `LICENSE`.
