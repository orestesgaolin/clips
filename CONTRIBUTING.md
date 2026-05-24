## Setup

Uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project:

```
brew install xcodegen
xcodegen generate
open Clips.xcodeproj
```

## CI/CD Release Pipeline

GitHub Actions now drives releases from version tags (`v*`) with:

- manual code signing (Developer ID and App Store certificates imported from secrets)
- Apple notarization and stapling
- Sparkle appcast generation and publishing via GitHub Pages
- changelog generation via `changelog_cli`
- GitHub Release upload and build provenance attestation
- App Store Connect upload via a separate manual workflow

### Required GitHub Secrets

- `APPLE_DEVELOPER_TEAM_ID` - Apple Developer Team ID
- `APP_STORE_CONNECT_KEY_ID` - App Store Connect API key ID
- `APP_STORE_CONNECT_ISSUER_ID` - App Store Connect API issuer ID
- `APP_STORE_CONNECT_API_KEY_BASE64` - base64 encoded `AuthKey_<KEY_ID>.p8`
- `MACOS_CERTIFICATE_P12` - base64 encoded Developer ID Application certificate (`.p12`)
- `MACOS_CERTIFICATE_PWD` - password for the Developer ID certificate
- `MACOS_CERTIFICATE_NAME` - Developer ID signing identity name
- `MACOS_PROVISIONING_PROFILE_BASE64` - base64 encoded Developer ID provisioning profile
- `MACOS_APP_STORE_CERTIFICATE_P12` - base64 encoded Apple Distribution certificate (`.p12`)
- `MACOS_APP_STORE_CERTIFICATE_PWD` - password for the Apple Distribution certificate
- `MACOS_APP_STORE_CERTIFICATE_NAME` - App Store signing identity name
- `MACOS_APP_STORE_PROVISIONING_PROFILE_BASE64` - base64 encoded Mac App Store provisioning profile
- `MACOS_APP_STORE_PROVISIONING_PROFILE_NAME` - Mac App Store provisioning profile name
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

### App Store Connect upload

Run the `App Store Connect` workflow manually with a marketing version. It archives the `ClipsAppStore` scheme, uploads the signed app to App Store Connect, and validates that the archive does not contain Sparkle metadata or `Sparkle.framework`. The App Store target uses `Clips/AppStore.entitlements` to enable the App Sandbox required by Mac App Store distribution.
