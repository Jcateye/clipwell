# Clipwell Plugin Pipeline Design

## Goal

Evolve Clipwell from a local clipboard history app into a local-first clipboard automation engine.

When the user copies content, Clipwell should be able to run a configurable chain of plugins. Each plugin receives the current runtime context, transforms or annotates it, and passes the updated context to the next plugin.

The design priorities are:

- Plugins are easy for outside developers to author.
- Plugins are easy for users to install, enable, disable, and reorder.
- The runtime passes rich context through the whole pipeline, not just raw text.
- Pipeline results are traceable back to the original clip.
- The system remains local-first and safe by default.

## Current Flow

The current capture path is centered on `ClipboardMonitorService.poll()`:

1. Detect `NSPasteboard` change.
2. Ignore paused state or ignored source apps.
3. Parse pasteboard with `ClipboardParser`.
4. Write payload data through `PayloadStore`.
5. Insert a `ClipItem` through `ClipRepository`.
6. Refresh drawer state.
7. Optionally run automatic OCR.

The plugin pipeline should be inserted after parsing and before or after history insertion depending on the plugin mode.

Recommended first implementation:

1. Save the original clip exactly as captured.
2. Build a `ClipPipelineContext` from that saved clip.
3. Run configured post-capture plugins.
4. Save plugin outputs as derived clips or context metadata.

This preserves the original clipboard history even if a plugin fails.

## Runtime Model

Pipeline execution is a sequence of stages:

```text
Original clipboard item
  -> Context
  -> Plugin stage 1
  -> Updated context
  -> Plugin stage 2
  -> Updated context
  -> Final context
  -> Persist derived clips / artifacts / UI state
```

The important rule is that plugins do not only receive `String` or `Data`. They receive a runtime context that carries source information, current content, artifacts, metadata, and stage history.

## Pipeline Ownership

The pipeline has four separate responsibilities:

- `ClipboardMonitorService` decides when a pipeline run should start. For example, after a new clipboard item is captured.
- `ClipPipelineRunner` owns ordering, stage selection, failure policy, and context handoff.
- `PluginExecutor` owns how a single plugin is executed. Built-in plugins and external WASM plugins use different executors.
- `EffectApplier` owns side effects such as saving derived clips, copying to pasteboard, pasting immediately, showing banners, or writing plugin data.

Plugins do not directly mutate global app state. A plugin returns an updated context and requested effects. Clipwell verifies permissions and applies the effects.

Recommended execution stack:

```text
ClipboardMonitorService
  -> ClipPipelineRunner
     -> BuiltInPluginExecutor
     -> WasmPluginExecutor
  -> EffectApplier
```

For built-in Swift plugins, the app executes compiled Swift code directly. For third-party plugins, the executor loads a WASM module and calls its `process` entrypoint through the Clipwell Plugin API v1 JSON ABI.

## Pipeline Arrangement

Users should think of a pipeline as an ordered list of stages. Each stage points to an installed plugin plus stage-specific rules.

```text
Post-copy pipeline
  1. OCR Image
  2. Translate Text
  3. Summarize Text
  4. Add Terms to Vocabulary
```

The order matters because every stage receives the context returned by the previous stage.

Example:

```text
Copied image
  -> OCR Image produces text
  -> Translate Text translates that text
  -> Summarize Text summarizes the translated text
  -> Save Derived Clip stores final result
```

### Pipeline Types

Clipwell should support several named pipelines instead of one global chain:

- `postCapture`: runs automatically after new clipboard capture.
- `manual`: runs when the user chooses an action from the drawer.
- `hotkey`: runs from a specific shortcut.
- `scheduled`: reserved for future background cleanup or batch processing.

Initial implementation should focus on `postCapture` and `manual`.

### Stage Configuration

Each stage in a pipeline should store:

```json
{
  "id": "stage-uuid",
  "pluginId": "com.example.markdown-cleaner",
  "enabled": true,
  "order": 20,
  "triggers": ["postCapture"],
  "contentTypes": ["text", "html"],
  "sourceAppRules": [],
  "failurePolicy": "continue",
  "settings": {}
}
```

Rules:

- `order` is the stable sort key. Use gaps like 10, 20, 30 so inserts do not require rewriting every stage.
- Disabled stages remain installed and configured but do not run.
- A stage only runs if trigger, content type, source app rules, and plugin `canProcess` all pass.
- If two stages have the same `order`, sort by stage ID for deterministic execution.
- Built-in stages and third-party stages use the same ordering model.

### Failure Policy

Each stage can choose:

- `continue`: record failure and continue to the next stage.
- `stop`: stop this pipeline run after failure.
- `manualReview`: stop and show the error for manual runs.

Defaults:

- `postCapture` uses `continue`.
- `manual` uses `manualReview`.
- Security or permission errors always stop the current plugin. They do not crash the pipeline runner.

### Content Handoff

The current context contains one canonical `current` content value plus optional artifacts.

- Use `current` for the main value that downstream plugins should process.
- Use `artifacts` for additional outputs that should remain available but not replace the main stream.
- Keep `originalClip` immutable so users can always trace back to the captured clipboard item.

Example:

```text
OCR plugin:
  originalClip = image
  current = text("recognized text")
  artifacts += ocr.text

Translate plugin:
  reads current text
  current = text("translated text")
  artifacts += translation.text
```

### Effect Application

Plugins can request effects, but Clipwell applies them after permission checks.

Supported first-version effects:

- `saveDerivedClip`: save the current content or artifact as a derived clip.
- `copyToPasteboard`: copy the current content to the system pasteboard.
- `pasteImmediately`: send paste keystroke after copying.
- `showBanner`: show a short status message in the drawer.

Effects should be applied after the pipeline run completes, not during each plugin call. This makes pipeline behavior easier to reason about and prevents half-applied side effects when a later stage fails.

## Core Types

```swift
struct ClipPipelineContext: Sendable {
    let runID: UUID
    let trigger: ClipPipelineTrigger
    let originalClip: ClipItem
    var current: ClipPipelineContent
    var source: ClipPipelineSource
    var metadata: [String: String]
    var artifacts: [ClipPipelineArtifact]
    var stageResults: [ClipPipelineStageResult]
    var requestedEffects: ClipPipelineEffects
}
```

```swift
enum ClipPipelineTrigger: Sendable {
    case postCapture
    case manual
    case scheduled
}
```

```swift
enum ClipPipelineContent: Sendable {
    case text(String)
    case richText(plainText: String?, payloadPath: String)
    case html(plainText: String?, payloadPath: String)
    case image(payloadPath: String)
    case file(url: URL)
    case media(url: URL?)
}
```

```swift
struct ClipPipelineSource: Sendable {
    var appName: String?
    var bundleIdentifier: String?
    var capturedAt: Date
}
```

```swift
struct ClipPipelineArtifact: Identifiable, Sendable {
    let id: UUID
    let kind: String
    let title: String
    let content: ClipPipelineContent
    let producerPluginID: String
    let metadata: [String: String]
}
```

```swift
struct ClipPipelineStageResult: Sendable {
    let pluginID: String
    let status: ClipPipelineStageStatus
    let startedAt: Date
    let endedAt: Date
    let message: String?
}
```

```swift
enum ClipPipelineStageStatus: Sendable {
    case skipped
    case succeeded
    case failed
}
```

```swift
struct ClipPipelineEffects: OptionSet, Sendable {
    let rawValue: Int

    static let saveDerivedClip = ClipPipelineEffects(rawValue: 1 << 0)
    static let copyToPasteboard = ClipPipelineEffects(rawValue: 1 << 1)
    static let pasteImmediately = ClipPipelineEffects(rawValue: 1 << 2)
    static let showBanner = ClipPipelineEffects(rawValue: 1 << 3)
}
```

## Plugin Interface

The stable in-process Swift interface should look like this:

```swift
protocol ClipPipelinePlugin: Sendable {
    var manifest: ClipPluginManifest { get }

    func canProcess(_ context: ClipPipelineContext) async -> Bool
    func process(_ context: ClipPipelineContext) async throws -> ClipPipelineContext
}
```

```swift
struct ClipPluginManifest: Codable, Sendable {
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let entrypoint: ClipPluginEntrypoint
    let supportedTriggers: [ClipPipelineTriggerName]
    let supportedContentTypes: [ClipPluginContentType]
    let requestedPermissions: [ClipPluginPermission]
}
```

The first-party Pro actions can later be adapted into built-in plugins:

- Image OCR
- Screenshot OCR
- AI translate
- AI rewrite
- AI summarize
- Add to vocabulary

That gives the same chain model to both built-in and third-party processors.

## Plugin Package Format

Third-party plugins should be distributed as folders or zip files with a manifest:

```text
Example.clipwellplugin/
  plugin.json
  main.wasm
  README.md
  icon.png
```

Recommended `plugin.json`:

```json
{
  "schemaVersion": 1,
  "id": "com.example.markdown-cleaner",
  "name": "Markdown Cleaner",
  "version": "1.0.0",
  "author": "Example Dev",
  "description": "Converts copied HTML or rich text into clean Markdown.",
  "entrypoint": {
    "kind": "wasm",
    "path": "main.wasm"
  },
  "supportedTriggers": ["postCapture", "manual"],
  "supportedContentTypes": ["text", "html", "rtf"],
  "requestedPermissions": ["readCurrentContent", "writeDerivedContent"]
}
```

## Clipwell Plugin API v1

External plugins should target a stable JSON ABI. The recommended authoring language is TypeScript compiled to WASM.

Authoring flow:

```text
TypeScript source
  -> npm run build
  -> main.wasm
  -> .clipwellplugin package
  -> installed by Clipwell
  -> executed by WasmPluginExecutor
```

The first official SDK should be `@clipwell/plugin-sdk`.

### Language Support

Version 1 should officially support:

- TypeScript through the Clipwell SDK and WASM build template.

Future compatible languages:

- Rust, Go, or any language that can compile to WASM and speak the same JSON ABI.

Native dynamic libraries should not be supported in the public plugin system until there is a strong signing, sandboxing, and crash-isolation story.

### Entrypoint

Each WASM plugin exposes one logical function:

```ts
export async function process(
  context: ClipPipelineContext
): Promise<ClipPipelineResult>
```

The executor serializes `ClipPipelineContext` to JSON, calls the WASM entrypoint, then decodes `ClipPipelineResult`.

### Context JSON

```json
{
  "schemaVersion": 1,
  "runId": "0AA497F1-96FE-4AA8-9377-7C7E97F2F8CC",
  "trigger": "postCapture",
  "originalClip": {
    "id": "clip-id",
    "type": "html",
    "plainText": "Hello",
    "sourceApp": "Safari",
    "createdAt": "2026-05-31T00:00:00Z"
  },
  "current": {
    "type": "text",
    "text": "Hello"
  },
  "source": {
    "appName": "Safari",
    "bundleIdentifier": "com.apple.Safari",
    "capturedAt": "2026-05-31T00:00:00Z"
  },
  "metadata": {},
  "artifacts": [],
  "stageResults": []
}
```

### Result JSON

```json
{
  "action": "replaceCurrent",
  "current": {
    "type": "text",
    "text": "Cleaned text"
  },
  "artifacts": [
    {
      "kind": "cleaned.text",
      "title": "Cleaned Text",
      "content": {
        "type": "text",
        "text": "Cleaned text"
      },
      "metadata": {}
    }
  ],
  "metadata": {
    "cleaner.whitespaceCollapsed": "true"
  },
  "effects": {
    "saveDerivedClip": true,
    "copyToPasteboard": false,
    "pasteImmediately": false,
    "showBanner": true
  },
  "message": "Cleaned text"
}
```

Valid result actions:

- `skip`: do not change context.
- `replaceCurrent`: replace the main `current` content.
- `appendArtifact`: add artifacts without replacing `current`.
- `fail`: return a controlled failure message.

### Minimal TypeScript Plugin

```ts
import type {
  ClipPipelineContext,
  ClipPipelineResult
} from "@clipwell/plugin-sdk";

export async function process(
  context: ClipPipelineContext
): Promise<ClipPipelineResult> {
  if (context.current.type !== "text") {
    return {
      action: "skip",
      message: "Only text is supported"
    };
  }

  const cleaned = context.current.text.trim().replace(/\s+/g, " ");

  return {
    action: "replaceCurrent",
    current: {
      type: "text",
      text: cleaned
    },
    artifacts: [
      {
        kind: "cleaned.text",
        title: "Cleaned Text",
        content: {
          type: "text",
          text: cleaned
        },
        metadata: {}
      }
    ],
    effects: {
      saveDerivedClip: true,
      copyToPasteboard: false,
      pasteImmediately: false,
      showBanner: true
    }
  };
}
```

### Developer Project Template

```text
markdown-cleaner/
  plugin.json
  package.json
  tsconfig.json
  src/
    index.ts
  README.md
```

Expected commands:

```sh
clipwell plugin init markdown-cleaner
cd markdown-cleaner
npm install
npm run build
clipwell plugin dev .
clipwell plugin pack .
```

`clipwell plugin dev` should run the plugin against sample contexts without requiring the full macOS app.

### Permissions

Permissions are declared in `plugin.json` and enforced by Clipwell:

```json
{
  "requestedPermissions": [
    "readCurrentContent",
    "readOriginalContent",
    "writeDerivedContent",
    "copyToPasteboard",
    "useNetwork"
  ]
}
```

Version 1 permission names:

- `readCurrentContent`
- `readOriginalContent`
- `writeDerivedContent`
- `copyToPasteboard`
- `pasteImmediately`
- `showBanner`
- `readClipboardFileURLs`
- `storePluginData`
- `useNetwork`

Default policy:

- `readCurrentContent` is required for most processors.
- `writeDerivedContent` is required to save artifacts as clips.
- `copyToPasteboard` and `pasteImmediately` require explicit user approval.
- `useNetwork` is disabled unless explicitly approved.
- Plugins never get unrestricted filesystem access.

## Entrypoint Strategy

Use a staged approach:

1. Built-in Swift plugins first.
2. Local development plugins loaded from a user plugin directory.
3. Sandboxed external plugins.

For external plugins, prefer WASM as the long-term default because it is easier to sandbox and package than arbitrary native code. Native Swift plugins can be considered later, but they create signing, ABI, crash isolation, and security problems.

Recommended directories:

```text
~/Library/Application Support/ClipboardDrawer/Plugins/
~/Library/Application Support/ClipboardDrawer/PluginData/
```

## Installation UX

Users should be able to install plugins by:

- Dragging a `.clipwellplugin` folder or zip into Settings.
- Clicking "Install Plugin" and choosing a local file.
- Opening a future marketplace/developer URL.

Install flow:

1. Read manifest.
2. Validate schema and plugin ID.
3. Verify the package contains the declared entrypoint.
4. Show requested permissions.
5. Copy package into the app plugin directory.
6. Mark plugin as installed but disabled by default if permissions are sensitive.
7. Let user enable and place it in a pipeline.

## Pipeline Configuration

Users should configure pipelines in Settings:

```text
Post-copy pipeline
  [x] OCR Image
  [x] Translate Text
  [ ] Summarize Text
  [x] Add Terms to Vocabulary
```

Each pipeline stage should have:

- Enabled state.
- Plugin name and version.
- Content type filters.
- Source app filters.
- Failure policy.
- Per-plugin settings.

Failure policy options:

- Stop pipeline on failure.
- Skip failed plugin and continue.
- Ask before continuing for manual runs.

Default should be "skip failed plugin and continue" for post-capture automation, because clipboard capture should remain reliable.

## Persistence Model

Keep the original clip immutable. Plugin outputs should be represented as derived clips or artifacts.

Recommended extension to `clips`:

- Existing `origin` and `derived_from_clip_id` already support this direction.
- Add stage metadata later if needed:
  - `pipeline_run_id`
  - `producer_plugin_id`
  - `producer_stage_index`

Optional future table:

```sql
CREATE TABLE pipeline_runs (
    id TEXT PRIMARY KEY,
    original_clip_id TEXT NOT NULL,
    trigger TEXT NOT NULL,
    started_at REAL NOT NULL,
    ended_at REAL,
    status TEXT NOT NULL
);
```

```sql
CREATE TABLE pipeline_stage_results (
    id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL,
    plugin_id TEXT NOT NULL,
    stage_index INTEGER NOT NULL,
    status TEXT NOT NULL,
    message TEXT,
    started_at REAL NOT NULL,
    ended_at REAL NOT NULL
);
```

## Security Model

Plugins should start with least privilege. Permissions should be explicit:

- Read current content.
- Read original content.
- Write derived content.
- Copy result to pasteboard.
- Paste immediately.
- Use network.
- Read files referenced by clipboard.
- Store plugin data.

Sensitive defaults:

- Network disabled unless explicitly allowed.
- File access limited to payload files and selected file URLs.
- Plugins cannot read full clipboard history unless a future permission allows it.
- Plugins cannot modify original clips.
- Plugin crashes or failures cannot break base clipboard capture.

## Developer Experience

The authoring path should be simple:

```sh
clipwell plugin init markdown-cleaner
clipwell plugin dev ./markdown-cleaner
clipwell plugin pack ./markdown-cleaner
```

Minimum developer docs should include:

- Manifest schema.
- Context schema.
- Input/output examples.
- Permission guide.
- Local test harness.
- Example plugins:
  - Text uppercase demo.
  - HTML to Markdown cleaner.
  - Image OCR wrapper.
  - Translate then summarize pipeline.

## Implementation Phases

### Phase 1: Internal Pipeline

- Add `ClipPipelineContext`.
- Add `ClipPipelinePlugin`.
- Add `ClipPipelineRunner`.
- Convert current automatic OCR path into an internal pipeline stage.
- Keep all plugins compiled into the app.

### Phase 2: Pipeline Configuration

- Add settings for enabled stages and order.
- Add per-content-type filters.
- Add failure policy.
- Add UI in Settings.

### Phase 3: Plugin Packages

- Add plugin manifest parser.
- Add local plugin directory scanner.
- Add install/uninstall flow.
- Show plugins in Settings.

### Phase 4: Sandboxed External Runtime

- Add WASM plugin runtime.
- Define stable JSON context ABI.
- Add permission enforcement.
- Add plugin data directory.

### Phase 5: Marketplace and Sharing

- Add signed plugin packages.
- Add update checks.
- Add plugin gallery or import URLs.
- Add developer publishing docs.

## First Engineering Step

The safest first code change is to introduce an internal-only `ClipPipelineRunner` and route the existing automatic OCR through it. That proves the context-passing model without exposing third-party execution yet.
