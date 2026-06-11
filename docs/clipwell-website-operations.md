# Clipwell Website Operations

## Production Environment

Clipwell's product website is a static site served from Cloudflare Pages.

- Primary domain: `https://clipwell.mioerlab.com/`
- Cloudflare Pages project: `clipwell-site`
- Pages fallback domain: `https://clipwell-site.pages.dev/`
- Source directory: `marketing/clipwell/`
- Production branch: `main`
- Company website backlink: `https://www.mioerlab.com/`

## DNS

The production subdomain is configured in the Cloudflare DNS zone for `mioerlab.com`.

```text
Type: CNAME
Name: clipwell
Target: clipwell-site.pages.dev
Proxy: Proxied
TTL: Auto
```

Cloudflare Pages also has `clipwell.mioerlab.com` added as a custom domain on the `clipwell-site` project. After DNS changes, Pages may show the domain as `pending` for a short period while HTTP validation completes.

## URLs for App Store Connect

Use these URLs for the Clipwell app record:

```text
Marketing URL: https://clipwell.mioerlab.com/
Privacy Policy URL: https://clipwell.mioerlab.com/privacy
Support URL: https://clipwell.mioerlab.com/support
```

## Deploy

Deploy from the repository root:

```sh
scripts/prepare_website_download.sh release
npx --yes wrangler@4.98.0 pages deploy marketing/clipwell --project-name clipwell-site --commit-dirty=true
```

`scripts/prepare_website_download.sh release` builds `dist/Clipwell.dmg` and copies it to `marketing/clipwell/downloads/Clipwell-latest.dmg`.

For public distribution outside the Mac App Store, use a Developer ID signed and notarized DMG. After storing notarytool credentials, notarize with:

```sh
NOTARYTOOL_PROFILE=clipwell-notary scripts/notarize_dmg.sh
```

If the site is deployed from another working directory, pass the absolute path:

```sh
/Users/haoqi/OnePersonCompany/cccv/scripts/prepare_website_download.sh release
npx --yes wrangler@4.98.0 pages deploy /Users/haoqi/OnePersonCompany/cccv/marketing/clipwell --project-name clipwell-site --commit-dirty=true
```

## Verification

After deploy, verify:

```sh
curl -I -L https://clipwell.mioerlab.com/
curl -I -L https://clipwell.mioerlab.com/privacy
curl -I -L https://clipwell.mioerlab.com/support
curl -I -L https://clipwell.mioerlab.com/downloads/Clipwell-latest.dmg
```

Expected result: each endpoint returns `200`.

## Brand and Legal

Current public-facing ownership copy:

```text
Mio Miao Labs LLC.
深圳市弥傲科技有限责任公司
```

The website footer and legal pages should stay aligned with this copy unless the App Store seller entity or company structure changes.
