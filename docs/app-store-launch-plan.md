# Clipwell Mac App Store Launch Plan

## Product Decision

Recommended product name: **Clipwell**

Company / seller identity:

- English: **Mio Miao Labs LLC.**
- Chinese legal name: **深圳市弥傲科技有限责任公司**

Positioning: a private, local-first clipboard drawer for Mac users who copy text, rich content, images, and files all day, but do not want another cloud sync surface.

App Store name: `Clipwell`

Subtitle: `Private Clipboard Drawer`

Short pitch: `A local clipboard drawer for Mac. Search, preview, and paste recent clips without sending clipboard history to a server.`

Why this name:

- Short, pronounceable, and under Apple's 30-character app name limit.
- "Well" suggests a deep local store without over-claiming security features.
- Less generic than "Clipboard Drawer" and easier to brand visually.

Name risk:

- A web search on April 28, 2026 found no obvious macOS clipboard app using "Clipwell", but this is not a trademark clearance. Confirm inside App Store Connect when creating the app record, then run a basic trademark/domain check before final submission.

Fallback names:

- **Clipdraw**: closer to current engineering name, but slightly less clear.
- **Copywell**: clear, but overlaps existing print/copy businesses.
- **Pastewell**: pleasant, but overlaps existing non-software usage.

## Launch Criteria

Ship the first App Store version only when all of these are true:

- App runs as a signed, sandboxed macOS app from an Xcode Archive.
- Clipboard history works inside the sandbox using the app container.
- Auto-paste behavior is either supported with clear permission messaging or disabled by default until Accessibility permission handling is polished.
- App has a proper `.icns` app icon and App Store 1024 x 1024 marketing icon.
- Privacy policy, support URL, screenshots, metadata, and review notes are complete.
- A clean install, upgrade, pause/resume, clear history, search, preview, hotkey, translation, and quit flow have been tested on at least macOS 15 and the current macOS release available to you.

## Phase 1: Store Readiness Audit

Current state:

- Swift Package executable named `ClipboardDrawer`.
- Manual `.app` packaging script with ad-hoc signing and downloadable zip output.
- `Info.plist` uses bundle ID `com.miomiaolabs.clipwell`, display name `Clipwell`, minimum macOS 15.0, and `LSUIElement=true`.
- No App Sandbox entitlements file is present.
- No Xcode project, Archive scheme, asset catalog, or App Store signing setup is present.
- App icon exports now exist as `Resources/Clipwell.icns` and `Resources/Clipwell-AppStore-1024.png`, generated from `marketing/clipwell/assets/icon.svg`.

Required changes:

1. Create an Xcode macOS App target that reuses the existing Swift source files.
2. Set product display name to `Clipwell`.
3. Choose final bundle ID, preferably `com.miomiaolabs.clipwell`.
4. Add App Sandbox entitlement. Apple states App Sandbox is required for Mac App Store distribution.
5. Add hardened runtime/signing configuration through Xcode archive flow.
6. Add app icon asset catalog for the future Xcode project. The current SwiftPM packaging flow already generates `.icns`.
7. Decide whether to preserve migration from `Application Support/ClipboardDrawer` to the sandbox container. For a new App Store launch with no external users, this can be skipped.

## Phase 2: App Behavior Hardening

Clipboard and privacy:

- Store history only in the app container.
- Add a first-run privacy note: "Clipwell stores clipboard history locally on this Mac. Nothing is uploaded."
- Keep "ignored apps" prominent for password managers and private apps.
- Add a one-click "Clear History" confirmation.
- Add a maximum history setting defaulting to 500, already implemented.

Permissions:

- Auto-paste uses synthetic Cmd+V events and may require Accessibility permission. Either:
  - Recommended for V1: keep auto-paste off by default, explain it in Settings, and show a permission helper only when the user enables it.
  - Simpler V1: remove/disable auto-paste for the first App Store build and paste by restoring to clipboard only.
- Global hotkey should fail visibly if registration fails, already partly implemented.

Review-sensitive items:

- Make it clear the app observes the general pasteboard because that is the product's core function.
- Avoid collecting analytics in V1.
- Do not request network access unless the app actually needs it.

## Phase 3: Build, Signing, and Upload

1. Enroll or confirm Apple Developer Program membership.
2. In Certificates, Identifiers & Profiles, create or confirm Mac App Store distribution assets.
3. Create bundle ID `com.miomiaolabs.clipwell`.
4. Build an Xcode Archive for `Any Mac`.
5. Validate archive locally.
6. Upload with Xcode Organizer or Transporter.
7. Wait for App Store Connect processing.
8. Attach the processed build to the macOS app version.

Apple currently documents that App Store Connect builds can be uploaded using Xcode, Transporter, altool, or App Store Connect API, and that an app record must exist before upload.

## Phase 4: App Store Connect Setup

Create the app record:

- Platform: macOS
- Name: `Clipwell`
- Primary language: English
- Bundle ID: `com.miomiaolabs.clipwell`
- SKU: `clipwell-macos-001`
- Seller / company: `Mio Miao Labs LLC.` / `深圳市弥傲科技有限责任公司`
- Category: Productivity or Utilities. Recommendation: Productivity.
- Age rating: likely 4+, assuming no web content or user sharing features.

App information:

- Subtitle: `Private Clipboard Drawer`
- Privacy Policy URL: product website privacy page
- Support URL: product website support page
- Marketing URL: product website homepage

Pricing:

- V1 recommendation: paid upfront at a low price, e.g. USD $2.99 or $4.99, no account and no IAP.
- Alternative: free V1 to collect adoption, paid Pro later. This adds future product complexity.

Privacy nutrition label:

- If V1 has no analytics, no cloud sync, no crash SDK, and no account system: answer that data is not collected.
- Clipboard contents stored locally on device are not "collected" by the developer if they never leave the user's device, but describe this clearly in the privacy policy.

Accessibility nutrition label:

- Complete App Store Connect's accessibility section for macOS. At minimum, test keyboard navigation, visible focus, VoiceOver labels for controls, contrast, and dynamic text behavior where applicable.

## Phase 5: Marketing Assets

Required Mac screenshots:

- Apple accepts 1 to 10 Mac screenshots with 16:10 aspect ratio, including 1280 x 800, 1440 x 900, 2560 x 1600, or 2880 x 1800.

Recommended screenshot set:

1. Drawer open on the side with clipboard history and search.
2. Rich preview pane showing formatted content or image.
3. Settings screen showing local controls and ignored apps.
4. Hotkey workflow: "Open with a shortcut, paste with Enter or Command-1."
5. Privacy-oriented screen: local history, pause, clear.

App Store description draft:

```text
Clipwell keeps your recent copies close without turning them into another cloud account.

Open a quiet side drawer from the menu bar or a global shortcut, search your recent clips, preview text, rich content, images, and documents, then restore the item you need to the clipboard.

Highlights:
• Local-first clipboard history
• Fast side drawer for recent clips
• Search and type filters
• Preview pane for text, rich text, HTML, images, and file references
• Keyboard-first paste workflow
• Pause monitoring, clear history, and ignore selected apps
• No account required

Clipwell is built for people who copy all day and want fewer interruptions, not more infrastructure.
```

Review notes draft:

```text
Clipwell is a macOS menu bar clipboard history utility. It monitors the general pasteboard while enabled, stores clipboard history locally in the app container, and lets the user search, preview, clear, and restore previous clipboard items.

No login is required. No network account is required. The app does not upload clipboard contents.

If auto-paste is enabled in Settings, the app may need Accessibility permission to send Cmd+V to the frontmost app. Auto-paste is optional and off by default.
```

## Phase 6: Website

The static product website is in `marketing/clipwell/`.

Pages:

- `index.html`: product landing page.
- `privacy.html`: App Store privacy policy URL candidate.
- `support.html`: App Store support URL candidate.
- `assets/icon.svg`: product icon direction.

Deployment options:

- Production: Cloudflare Pages project `clipwell-site`.
- Primary URL: `https://clipwell.mioerlab.com/`.
- Fallback URL: `https://clipwell-site.pages.dev/`.
- DNS: `clipwell.mioerlab.com` CNAME to `clipwell-site.pages.dev`, proxied in Cloudflare.
- Operations runbook: `docs/clipwell-website-operations.md`.

## Phase 7: Release Sequence

Week 1:

- Rename user-facing app strings to Clipwell.
- Create Xcode target, entitlements, asset catalog, signing setup.
- Decide auto-paste permission handling.
- Add first-run privacy message and support/privacy menu links.

Week 2:

- QA signed sandbox build.
- Generate screenshots and app icon exports.
- Finalize App Store Connect metadata and privacy answers.
- Upload first TestFlight/internal build if desired.

Week 3:

- Submit for App Review.
- Respond quickly to metadata or permission questions.
- Release manually after approval.
- Post website and basic launch announcement.

## Official References Checked

- Apple App Sandbox for Mac App Store distribution: https://developer.apple.com/documentation/security/app_sandbox
- Configuring the macOS App Sandbox: https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox/
- App Store Connect app information and app name/subtitle limits: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- Add a new app record: https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app
- Upload builds: https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- Screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications/
- App privacy details: https://developer.apple.com/app-store/app-privacy-details/
