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
