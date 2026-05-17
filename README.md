# Clips

A lightweight macOS clipboard manager that lives in your menu bar.

![](docs/screenshot_menu.png)

## Features

- Clipboard history with rich content support
- Global hotkey (Cmd+Shift+V) to show history
- Number keys (1-9) for quick selection, with folder navigation

## Requirements

- macOS 15 (Sequoia) or later
- Accessibility permission (for paste simulation)

## Setup

Uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project:

```
brew install xcodegen
xcodegen generate
open Clips.xcodeproj
```

## CI/CD Release Pipeline

GitHub Actions now drives releases from version tags (`v*`) with:

- automatic code signing (Developer ID, automatic provisioning)
- Apple notarization and stapling
- Sparkle appcast generation and publishing via GitHub Pages
- changelog generation via `changelog_cli`
- GitHub Release upload and build provenance attestation

### Required GitHub Secrets

- `APPLE_CERTIFICATE_P12_BASE64` - base64 encoded Developer ID Application certificate (`.p12`)
- `APPLE_CERTIFICATE_PASSWORD` - password for the `.p12`
- `APPLE_DEVELOPER_TEAM_ID` - Apple Developer Team ID
- `APP_STORE_CONNECT_KEY_ID` - App Store Connect API key ID
- `APP_STORE_CONNECT_ISSUER_ID` - App Store Connect API issuer ID
- `APP_STORE_CONNECT_API_KEY_BASE64` - base64 encoded `AuthKey_<KEY_ID>.p8`
- `SPARKLE_PUBLIC_ED_KEY` - Sparkle public EdDSA key embedded in app
- `SPARKLE_PRIVATE_ED_KEY` - Sparkle private EdDSA key used to sign appcast

### Sparkle Keys

Generate Sparkle keys once and keep private key in GitHub secrets:

```sh
curl -Ls https://github.com/sparkle-project/Sparkle/releases/download/2.9.2/Sparkle-2.9.2.tar.xz -o sparkle.tar.xz
tar -xJf sparkle.tar.xz
./bin/generate_keys
```

Use the reported public key for `SPARKLE_PUBLIC_ED_KEY` and private key for `SPARKLE_PRIVATE_ED_KEY`.

### Triggering a release

```sh
git tag v1.0.0
git push origin v1.0.0
```

The `Release` workflow will build, sign, notarize, publish release assets, and deploy Sparkle metadata to GitHub Pages.

## Preferences

![](docs/screenshot_app.png)

- **General** — launch at login, max history, sort order, paste shortcut
- **Appearance** — icon style, inline/folder item counts, character limits, inline images
- **History** — search, copy, and delete entries
- **Ignored Apps** — exclude apps from clipboard monitoring

# Acknowledgements

App inspired by [Clipy](https://github.com/Clipy/Clipy).
