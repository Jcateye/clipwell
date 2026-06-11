# Clipwell for Windows

Native Windows client for Clipwell, built with **.NET 8 + WPF**. It mirrors the macOS
app's product design and data structures (same SQLite schema, payload file layout, and
settings semantics) but is an independent codebase — the macOS Swift app stays untouched.

## MVP scope

- System tray resident app (single instance)
- Global hotkey (default `Ctrl+Shift+V`) toggles an edge-docked drawer
- Clipboard monitoring via `AddClipboardFormatListener` (text, image, file drop, RTF, HTML)
- SQLite history at `%APPDATA%\Clipwell\clips.sqlite` + binary payloads in `payloads\`
- Search, type filter, restore to clipboard, pin, delete
- Settings (`%APPDATA%\Clipwell\settings.json`): history limit, launch at login, hotkey,
  pause monitoring, ignored apps/extensions, drawer edge/width

Out of scope for now (seam left via `IClipPostProcessor`): OCR, AI translate/summarize/rewrite,
auto-paste, plugin pipeline.

## Project layout

| Project | TFM | Purpose |
|---|---|---|
| `src/Clipwell.Core` | `net8.0` | Models, SQLite repository, payload store, settings — no Windows dependencies, testable on macOS/Linux |
| `src/Clipwell.Win` | `net8.0-windows` | WPF app: tray, drawer, settings UI, Win32 interop |
| `tests/Clipwell.Core.Tests` | `net8.0` | xUnit tests, run anywhere with `dotnet test` |

## Building

### On Windows

```powershell
dotnet build Clipwell.Win.sln -c Release
dotnet run --project src/Clipwell.Win
```

### On macOS / Linux (compile check + tests only)

The WPF project sets `EnableWindowsTargeting`, so the whole solution compiles on a Mac,
but the app can only *run* on Windows.

```bash
brew install --cask dotnet-sdk   # once
dotnet build Clipwell.Win.sln
dotnet test tests/Clipwell.Core.Tests
```

CI builds and tests on `windows-latest` for every push touching `windows/**`
(`.github/workflows/windows-build.yml`) and uploads a runnable publish artifact.

## Manual smoke checklist (run on a Windows machine)

1. Launch — tray icon appears; a second launch exits immediately (single instance).
2. Copy text, an image, and a file from three different apps — each shows up in the
   drawer with the correct type and source app.
3. Press `Ctrl+Shift+V` — drawer toggles, search box focused; Esc and focus loss hide it.
4. Type in search — list filters; tabs filter by type.
5. Double-click a clip — it is restored to the clipboard (and not re-captured as a new entry).
6. Pin a clip, fill history past the limit — the pinned clip survives pruning.
7. Toggle "Launch at login" — `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\Clipwell`
   appears/disappears.
8. Pause monitoring from the tray menu — copies are no longer recorded.

Highest-risk areas that cannot be verified off-Windows: clipboard listener lifetime,
hotkey conflicts, CF_HTML header parsing, and Deactivated behavior of the topmost drawer.

## Data compatibility with macOS

The `clips` table DDL, type/origin enum strings (`text|rtf|html|media|document`,
`original|proDerived`), `payloads/{id}.{ext}` naming, and Unix-epoch REAL timestamps are
identical to the macOS app, keeping future sync/import straightforward.

## Packaging (later)

Planned route: Inno Setup over a `dotnet publish -r win-x64 --self-contained` output
(MSIX as an alternative if Store distribution becomes interesting). Not scaffolded yet.
