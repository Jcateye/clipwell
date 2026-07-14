# Clipwell Store Submission Checklist

## Current submission status (2026-07-14)

### Apple

- Existing App Store Connect record: Apple ID `6785804578`, bundle ID `com.miomiaolabs.clipwell`, SKU `clipwell-macos-001`.
- Product name saved as `Clipwell`; category is Productivity; age rating is 4+.
- Paid Apps Agreement is in effect for `MioMiao Labs LLC`.
- United States base price is **USD $0.99** with automatic local prices in 175 countries or regions.
- Public distribution and availability in all 175 countries or regions are configured for app release.
- Universal macOS 1.0.0 build 1 (Apple Silicon + Intel) was uploaded successfully and is processing.
- A privacy-safe 1440 × 900 listing image is ready at `marketing/clipwell/store-assets/mac/clipwell-store-01.png`.
- App Review contact information is saved with phone `+16267842766` and email `support@mioerlab.com`.
- Universal build 1 is selected for version 1.0.0, and the version metadata/review notes are saved.
- Remaining submission work: upload the prepared screenshot, update App Privacy and the new social-media age-rating answers, then add the version for review.

### Microsoft

- Company onboarding and developer vetting are authorized.
- The legacy EXE/MSI product was renamed to `Clipwell Legacy Installer`, and its `Clipwell` reservation was released for migration to an MSIX product.
- Store assets and the Partner Center identity-driven MSIX packaging script are ready. A manually triggered GitHub Actions job can build and validate the final Store MSIX after the identity values are available.
- Creating the MSIX product is currently blocked because `xuxunjian2022@outlook.com` has no app-registration permission in Partner Center tenant `9188040d-6c67-4c5b-b112-36a304b66dad`. A tenant administrator must assign that user the built-in **Application Developer** role (or create the product on its behalf).
- After that role is active, reserve `Clipwell`, copy the Product identity values, run the Store MSIX workflow, upload the artifact, and configure the paid **USD $0.99** submission.

## Commercial model

- macOS: paid Mac App Store app, one-time purchase, US base price **USD $0.99**.
- Windows: paid Microsoft Store app, one-time purchase, US base price **USD $0.99**.
- No subscription, in-app purchase, account, license key, or payment SDK.
- Apple and Microsoft handle checkout, receipts, refunds, regional pricing, and applicable marketplace tax collection. Store proceeds are paid to the configured company bank account after store fees, withholding, and thresholds.
- A Mac purchase and a Windows purchase are separate. Neither store can automatically honor a purchase made in the other store. Cross-platform entitlement would require an account and independent licensing backend, which is intentionally out of scope for the $0.99 launch.

## Accounts and payout — owner action required

### Apple

1. Confirm the Apple Developer organization is the intended seller and the legal entity name is correct.
2. In App Store Connect > Business, accept the current **Paid Apps Agreement** as Account Holder.
3. Complete the tax forms and add the company bank account.
4. If eligible, enroll in the App Store Small Business Program (15% commission).
5. Create the macOS app record with bundle ID `com.miomiaolabs.clipwell` and SKU `clipwell-macos-001`.
6. Set the United States base storefront to the available **$0.99** price point and allow automatic equivalent pricing elsewhere.

### Microsoft

1. Confirm the Partner Center developer account is an organization account for the intended seller.
2. In Partner Center > Account settings > Payout and tax, complete and validate the tax and payout profiles.
3. Reserve the product name `Clipwell`.
4. Copy the exact **Package/Identity/Name**, **Publisher**, and **Publisher display name** values from Product identity. They are required to create the final MSIX.
5. Create a paid app submission and select the **$0.99** base price tier.

Do not place bank details, tax IDs, certificates, API keys, or Partner Center secrets in this repository.

## macOS package

The App Store target is generated from `project.yml`:

```bash
./scripts/generate_app_icon.sh
xcodegen generate
open Clipwell.xcodeproj
```

In Xcode:

1. Select the Clipwell target > Signing & Capabilities.
2. Choose the Apple Developer organization team and confirm automatic signing succeeds.
3. Product > Archive using Any Mac (Apple Silicon, Intel).
4. In Organizer, choose Distribute App > App Store Connect > Upload.

The target uses App Sandbox plus outbound network access for the optional user-configured AI endpoint. Clipboard history remains local in the app container.

## Windows package

On Windows with .NET 8 SDK and Windows SDK installed, use the exact identity values copied from Partner Center:

```powershell
.\store\package-store.ps1 `
  -IdentityName "PASTE_PARTNER_CENTER_IDENTITY_NAME" `
  -Publisher "PASTE_PARTNER_CENTER_PUBLISHER" `
  -PublisherDisplayName "MioMiao Labs LLC" `
  -Version "1.0.0.0"
```

This creates `dist/Clipwell-1.0.0.0-win-x64.msix`. Upload it in the Partner Center submission. Microsoft signs Store-delivered MSIX packages after certification.

The same package can be produced from GitHub Actions by manually running **Windows Build** and supplying the exact `Package/Identity/Name`, `Package/Identity/Publisher`, and four-part package version. The workflow uploads the validated MSIX as a build artifact.

## Listing metadata

- Product name: `Clipwell`
- Category: Productivity
- Short positioning: `A private, local-first clipboard drawer.`
- Privacy: clipboard data is stored locally; no analytics or account data is collected. Optional AI actions send only user-requested content to the endpoint the user configures.
- Privacy URL: `https://clipwell.mioerlab.com/privacy.html`
- Support URL: `https://clipwell.mioerlab.com/support.html`
- Support email: `support@mioerlab.com`
- Marketing URL: `https://clipwell.mioerlab.com/`

## Submission gates

- Mac archive validates with App Store distribution signing and sandbox entitlements.
- Windows MSIX passes Windows App Certification Kit on a clean Windows machine.
- Test clean install, launch at login, clipboard monitoring, global shortcut, screenshot permissions, auto-paste permission messaging, clear history, and uninstall on both platforms.
- Capture platform-specific screenshots; do not reuse Mac screenshots for the Windows listing.
- Before release, remove or restrict the legacy `/download/latest` direct-download endpoint so it cannot bypass the paid stores.
- Remove debug-only stderr logging before the release archive.
- Verify the final privacy answers against the shipped network behavior.
