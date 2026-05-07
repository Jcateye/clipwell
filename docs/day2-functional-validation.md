# Clipwell Day 2 Functional Validation

Date: 2026-05-07

## Automated Checks

### 1. Unit Test Baseline

Command:

```sh
swift test
```

Result:

```text
12 tests, 0 failures
```

Covered areas:

- Repository pruning and filtered deletion
- Media filtering for copied media files
- Settings persistence for ignored apps/file extensions, shortcuts, and AI provider settings
- Shortcut conflict validation
- Vocabulary store de-duplication
- Vocabulary view-model delete/refresh

### 2. Isolated Clipboard Smoke

Used an isolated data directory via `CLIPBOARD_DRAWER_DATA_DIR` so the user's real Clipwell history database was not touched.

Checks performed:

- Launched `swift run ClipboardDrawer` with isolated storage.
- Copied a unique text value via `pbcopy`.
- Verified latest SQLite row contained `type=text`, the exact copied text, and `origin=original`.
- Copied a local Markdown file as a Finder-style file URL via AppleScript clipboard assignment.
- Verified SQLite captured a `document` row containing the file path.
- Restored the original clipboard content after the smoke test.

Result:

```text
clipboard smoke passed
```

### 3. Package Smoke

Command:

```sh
scripts/package_app.sh debug
```

Checks performed:

- Built `.build/app/ClipboardDrawer.app`.
- Verified bundle metadata:
  - `CFBundleIdentifier`: `com.miomiaolabs.clipwell`
  - `CFBundleDisplayName`: `Clipwell`
  - `LSUIElement`: `true`
- Launched the packaged executable briefly.
- Terminated it cleanly.
- Checked launch log for obvious fatal/uncaught errors.

Result:

```text
package smoke passed
```

## Fixes Made During Validation

### `scripts/package_app.sh` stdout cleanliness

Problem:

- The package script printed `swift build` logs to stdout before the final app path.
- This made command substitution unreliable for automation, because `APP_PATH="$(scripts/package_app.sh debug)"` captured logs plus the path.

Fix:

- Redirected build logs to stderr.
- Suppressed `--show-bin-path` stderr.
- Kept stdout as the final `.app` path only.

## Manual GUI/OCR Checklist

These require user interaction or macOS permission prompts, so they were documented for manual validation rather than automated in this pass.

### Drawer Basics

- Open drawer with global shortcut.
- Confirm latest copied text appears at top.
- Search text history.
- Switch filters: All / Text / Media / Document.
- Toggle preview on/off and adjust preview height.
- Use arrow keys to move selection.
- Press Return to paste selected clip.
- Use `⌘1`-`⌘9` to paste visible candidates.
- Use clear-current-category and confirm destructive dialog.

### Settings

- Change visual theme and confirm drawer/settings repaint immediately.
- Change ignored app list and confirm capture pauses for matching app.
- Change ignored file suffixes and confirm copied matching files are ignored.
- Change toggle drawer shortcut.
- Try duplicate shortcut and confirm conflict warning/block.
- Change screenshot OCR shortcut.

### Pro OCR

- Copy a screenshot/image containing English text, run Image OCR, confirm result appears in history as Pro-derived text.
- Copy a screenshot/image containing Chinese text, run Image OCR, confirm configured languages work acceptably.
- Trigger Screenshot OCR shortcut.
- Cancel screenshot selection and confirm no scary error is shown.
- If macOS prompts for permissions, confirm the user-facing message is understandable.

### Vocabulary

- Add a text clip to vocabulary.
- Open Vocabulary window from settings/menu.
- Search vocabulary.
- Delete an item and confirm list refreshes.
- Add duplicate text and confirm it de-duplicates.

### AI Actions

- With no API key configured, run Translate/Rewrite/Summarize and confirm the error is understandable.
- Configure an OpenAI-compatible endpoint.
- Test connection.
- Run Translate/Rewrite/Summarize on a text clip.
- Confirm result is saved to history and marked as Pro-derived.

## Day 2 Result

Automated validation passed for unit tests, isolated clipboard capture, and packaging/launch smoke. Remaining validation is GUI/OCR/AI manual flow testing.
