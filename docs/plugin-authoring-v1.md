# Clipwell Plugin Authoring v1

This document is the public-facing contract for third-party Clipwell plugins.

## What A Plugin Does

A Clipwell plugin receives clipboard pipeline context, processes it, and returns a result.

Plugins can:

- Read the current pipeline content.
- Read limited original clip metadata.
- Replace the current content for downstream plugins.
- Add artifacts such as OCR text, cleaned text, translations, summaries, or extracted URLs.
- Request controlled effects such as saving a derived clip or copying a result to pasteboard.

Plugins cannot directly:

- Mutate Clipwell history.
- Read full clipboard history.
- Read arbitrary files.
- Write to the system pasteboard without permission.
- Send network requests without permission.
- Execute native code.

Clipwell owns all side effects.

## Recommended Language

Version 1 plugins should be written in TypeScript with `@clipwell/plugin-sdk` and compiled to WASM.

```text
TypeScript -> WASM -> .clipwellplugin -> Clipwell WasmPluginExecutor
```

Other languages may be supported later if they compile to WASM and implement the same JSON ABI.

## Package Layout

```text
my-plugin.clipwellplugin/
  plugin.json
  main.wasm
  README.md
  icon.png
```

## Manifest

`plugin.json` describes the plugin and the permissions it requests.

```json
{
  "schemaVersion": 1,
  "id": "com.example.markdown-cleaner",
  "name": "Markdown Cleaner",
  "version": "1.0.0",
  "author": "Example Dev",
  "description": "Converts copied HTML or text into clean Markdown.",
  "entrypoint": {
    "kind": "wasm",
    "path": "main.wasm"
  },
  "triggers": ["postCapture", "manual"],
  "contentTypes": ["text", "html", "rtf"],
  "permissions": [
    "readCurrentContent",
    "writeDerivedContent",
    "showBanner"
  ]
}
```

## Entrypoint

Every plugin exports `process`.

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
    },
    message: "Cleaned text"
  };
}
```

## Context

Clipwell passes a JSON context to the plugin.

```ts
type ClipPipelineContext = {
  schemaVersion: 1;
  runId: string;
  trigger: "postCapture" | "manual" | "hotkey" | "scheduled";
  originalClip: OriginalClip;
  current: ClipContent;
  source: ClipSource;
  metadata: Record<string, string>;
  artifacts: ClipArtifact[];
  stageResults: ClipStageResult[];
};
```

Content types:

```ts
type ClipContent =
  | { type: "text"; text: string }
  | { type: "html"; plainText?: string; payloadRef: string }
  | { type: "rtf"; plainText?: string; payloadRef: string }
  | { type: "image"; payloadRef: string }
  | { type: "file"; fileRef: string }
  | { type: "media"; fileRef?: string; payloadRef?: string };
```

`payloadRef` and `fileRef` are opaque references. They are not unrestricted filesystem paths. The executor decides whether the plugin may read them based on permissions.

## Result

```ts
type ClipPipelineResult = {
  action: "skip" | "replaceCurrent" | "appendArtifact" | "fail";
  current?: ClipContent;
  artifacts?: ClipArtifact[];
  metadata?: Record<string, string>;
  effects?: ClipPipelineEffects;
  message?: string;
};
```

```ts
type ClipPipelineEffects = {
  saveDerivedClip?: boolean;
  copyToPasteboard?: boolean;
  pasteImmediately?: boolean;
  showBanner?: boolean;
};
```

## Pipeline Behavior

Plugins run in user-defined order.

```text
Stage 1 output -> Stage 2 input -> Stage 3 input
```

Use `replaceCurrent` when downstream plugins should process your output. Use `appendArtifact` when your output should be visible or saved but should not replace the main stream.

Example:

```text
OCR Image:
  image -> text

Translate:
  text -> translated text

Summarize:
  translated text -> summary
```

## Permissions

Supported v1 permissions:

- `readCurrentContent`
- `readOriginalContent`
- `writeDerivedContent`
- `copyToPasteboard`
- `pasteImmediately`
- `showBanner`
- `readClipboardFileURLs`
- `storePluginData`
- `useNetwork`

Sensitive permissions are shown during install and can be disabled by the user.

## Development Commands

Expected CLI flow:

```sh
clipwell plugin init markdown-cleaner
cd markdown-cleaner
npm install
npm run build
clipwell plugin dev .
clipwell plugin pack .
```

`clipwell plugin dev` should run the plugin against sample contexts:

```sh
clipwell plugin dev . --sample text
clipwell plugin dev . --sample html
clipwell plugin dev . --sample image
```

## Installation

Users install plugins by:

- Dragging `.clipwellplugin` into Clipwell Settings.
- Choosing a local plugin package.
- Opening a future Clipwell plugin URL.

Clipwell validates the manifest, checks the entrypoint, displays permissions, copies the package to the plugin directory, and lets the user add it to a pipeline.

