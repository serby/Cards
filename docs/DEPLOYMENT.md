# Deployment Pipeline

This project uses GitHub Actions driving plain `xcodebuild` and the shell
scripts in `scripts/` for automated deployment.

## Infrastructure as Code

### GitHub Actions Workflows

#### CI Workflow (`.github/workflows/ci.yml`)
- Triggers on push to `main` and pull requests
- Runs on macOS 15
- Executes build and test via Makefile
- Uploads test results as artifacts

#### Deploy Workflow (`.github/workflows/deploy.yml`)
- Triggers on version tags (`v*`) or manual dispatch
- Builds and deploys to TestFlight
- Manages certificates and provisioning profiles
- Runs `scripts/deploy-testflight.sh`

### Build and Deploy Scripts

`scripts/build-ipa.sh` archives the app in Release and exports a signed `.ipa`,
and the deploy scripts upload it with `xcrun altool`:
- `scripts/deploy-testflight.sh` - archive, export, upload to TestFlight
- `scripts/deploy-appstore.sh` - archive, export, upload to App Store Connect
- `scripts/asc-submit.sh` - create the version and submit for review

Signing defaults to manual against the "Card Codes Wallet App Store Profile"
that CI installs into `~/Library/MobileDevice/Provisioning Profiles`. Override
with `PROVISIONING_PROFILE_SPECIFIER`, `CODE_SIGN_IDENTITY` or `EXPORT_METHOD`.

#### Appfile
Configures app identifiers and team IDs via environment variables.

## Required Secrets

Configure these in GitHub repository settings → Secrets and variables → Actions:

### Apple Developer Account
- `APPLE_ID` - Apple Developer email
- `ITC_TEAM_ID` - App Store Connect Team ID
- `TEAM_ID` - Developer Portal Team ID
- `APP_STORE_CONNECT_API_KEY` - App-specific password

### Code Signing
- `BUILD_CERTIFICATE_BASE64` - Base64 encoded .p12 certificate
- `P12_PASSWORD` - Certificate password
- `BUILD_PROVISION_PROFILE_BASE64` - Base64 encoded provisioning profile
- `KEYCHAIN_PASSWORD` - Temporary keychain password

## Setup Instructions

### 1. Install Dependencies
Only Xcode is required — the build is a plain Xcode project driven by
`xcodebuild`, and the deploy scripts use `xcrun altool`.
```bash
xcode-select --install
```

### 2. Export Certificates
```bash
# Export certificate from Keychain as .p12
# Then encode to base64
base64 -i certificate.p12 | pbcopy

# Export provisioning profile
base64 -i profile.mobileprovision | pbcopy
```

### 3. Configure GitHub Secrets
Add all required secrets to repository settings.

### 4. Deploy

#### Manual TestFlight Deployment
```bash
make deploy-testflight
```

#### Automated Deployment
Push a version tag:
```bash
git tag v1.0.0
git push origin v1.0.0
```

Or trigger manually via GitHub Actions UI.

## Local Development

### Run Tests
```bash
make test          # unit + UI
make test-unit     # CardsTests only
make test-e2e      # CardsUITests only
```

### Build
```bash
make build
```

## Deployment Flow

1. Developer pushes code to `main`
2. CI workflow runs tests
3. On success, developer creates version tag
4. Deploy workflow triggers automatically
5. The deploy workflow archives, exports and uploads to TestFlight
6. Build appears in App Store Connect

## Troubleshooting

### Certificate Issues
- Ensure certificate is valid and not expired
- Check provisioning profile matches bundle identifier
- Verify team IDs are correct

### Build Failures
- Check Xcode version compatibility
- Verify all dependencies are resolved
- Review build logs in GitHub Actions

### Upload Errors
- Check Apple Developer account status
- Verify the ASC API key (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`)
- Confirm the exported profile matches the bundle identifier
