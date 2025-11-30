# Deployment Pipeline

This project uses GitHub Actions and Fastlane for automated deployment.

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
- Uses Fastlane for deployment automation

### Fastlane Configuration

#### Fastfile
Defines deployment lanes:
- `test` - Run unit and UI tests
- `build` - Build for testing
- `beta` - Deploy to TestFlight
- `release` - Deploy to App Store

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

### 1. Install Fastlane
```bash
brew install fastlane
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
fastlane beta
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
make test
# or
fastlane test
```

### Build
```bash
make build
# or
fastlane build
```

## Deployment Flow

1. Developer pushes code to `main`
2. CI workflow runs tests
3. On success, developer creates version tag
4. Deploy workflow triggers automatically
5. Fastlane builds and uploads to TestFlight
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

### Fastlane Errors
- Run `fastlane update_fastlane` to update
- Check Apple Developer account status
- Verify API keys and passwords are correct
