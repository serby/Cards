# CI/CD Setup Guide

## Prerequisites
- GitHub repository for the project
- Apple Developer account
- Xcode with valid signing certificate

## Step 1: Push Code to GitHub

```bash
# If not already initialized
git remote add origin https://github.com/[your-username]/Cards.git
git push -u origin main
```

## Step 2: Export Certificates

### Export Distribution Certificate
```bash
# Open Keychain Access
# Find "Apple Distribution: [Your Name]" certificate
# Right-click → Export "Apple Distribution..."
# Save as distribution.p12 with a password

# Encode to base64
base64 -i distribution.p12 | pbcopy
```
Save this as `BUILD_CERTIFICATE_BASE64` secret (copied to clipboard)

### Provisioning profiles

None to export. CI creates and installs the App Store profiles for the app and its widget through the App Store Connect API on every run (`scripts/install-signing-profiles.ts`, see `docs/DEVELOPMENT.md` section 7). The `BUILD_PROVISION_PROFILE_BASE64` secret is no longer read and can be deleted.

## Step 3: Get Apple IDs

### Team IDs
```bash
# Go to https://developer.apple.com/account
# Click "Membership" → Copy Team ID
```
This is your `TEAM_ID`: **ZMBFPG86J4**

```bash
# Go to https://appstoreconnect.apple.com
# Click your name (top right) → View Membership
# Copy Team ID
```
This is your `ITC_TEAM_ID`

### App-Specific Password
```bash
# Go to https://appleid.apple.com
# Sign in → App-Specific Passwords
# Generate new password for "GitHub Actions"
```
Save as `APP_STORE_CONNECT_API_KEY`

## Step 4: Configure GitHub Secrets

Go to: `https://github.com/[your-username]/Cards/settings/secrets/actions`

Click "New repository secret" for each:

| Secret Name | Value | Where to Find |
|------------|-------|---------------|
| `APPLE_ID` | Your Apple ID email | Your Apple account email |
| `TEAM_ID` | ZMBFPG86J4 | Already set in project |
| `ITC_TEAM_ID` | [Your ITC Team ID] | App Store Connect → Membership |
| `BUILD_CERTIFICATE_BASE64` | [Base64 certificate] | From Step 2 |
| `P12_PASSWORD` | [Certificate password] | Password you set when exporting |
| `KEYCHAIN_PASSWORD` | [Any secure password] | Create a strong password |
| `APP_STORE_CONNECT_API_KEY` | [App-specific password] | From Step 3 |

## Step 5: Test CI Pipeline

```bash
# Commit and push changes
git add .
git commit -m "chore: setup CI/CD pipeline"
git push origin main
```

Go to: `https://github.com/[your-username]/Cards/actions`

You should see the CI workflow running.

## Step 6: Test Deployment

```bash
# Create a version tag
git tag v1.0.0
git push origin v1.0.0
```

This triggers `release.yml`, which builds, uploads and submits the version for App Store review. Pushes to `main` only run CI.

## Troubleshooting

### "No signing certificate found"
- Ensure you exported the **Distribution** certificate, not Development
- Verify the base64 encoding is correct (no extra spaces/newlines)

### "Profile doesn't match bundle identifier"
- Download the correct profile for `net.serby.cards`
- Ensure it's an App Store profile, not Development

### "Authentication failed"
- Verify `APPLE_ID` is correct
- Check `APP_STORE_CONNECT_API_KEY` is an app-specific password
- Ensure 2FA is enabled on your Apple ID

### Workflow doesn't trigger
- Check `.github/workflows/` files are committed
- Verify branch name is `main` (not `master`)
- Check Actions are enabled in repository settings
