# Clipwell

Clipwell is a local-first clipboard drawer for macOS by MioMiao Labs LLC.

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

Package a local `.app` bundle:

```sh
scripts/package_app.sh release
```

The current Swift Package executable target is still named `ClipboardDrawer`. User-facing App Store branding is `Clipwell`.

## App Store Preparation

The App Store launch plan and marketing website are included in:

- `docs/app-store-launch-plan.md`
- `marketing/clipwell/`

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
