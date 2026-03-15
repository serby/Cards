# CI/CD Setup Guide

## Prerequisites
- GitHub repository for the project
- Apple Developer account
- Xcode with valid signing certificate
- [Bazelisk](https://github.com/bazelbuild/bazelisk) (`brew install bazelisk`)

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

### Export Provisioning Profile
```bash
# Download from https://developer.apple.com/account
# Certificates, Identifiers & Profiles → Profiles
# Download the App Store profile for net.serby.cards

# Encode to base64
base64 -i Cards_AppStore.mobileprovision | pbcopy
```
Save this as `BUILD_PROVISION_PROFILE_BASE64` secret

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
| `BUILD_PROVISION_PROFILE_BASE64` | [Base64 profile] | From Step 2 |
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

This will trigger the deployment workflow and upload to TestFlight.

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

## Quick Setup Script

Run this to check your setup:

```bash
#!/bin/bash

echo "Checking CI/CD setup..."

# Check if GitHub remote exists
if git remote get-url origin &> /dev/null; then
    echo "✅ GitHub remote configured"
else
    echo "❌ No GitHub remote found"
fi

# Check if workflows exist
if [ -d ".github/workflows" ]; then
    echo "✅ Workflow files exist"
else
    echo "❌ No workflow files found"
fi

# Check if Fastlane is configured
if [ -f "fastlane/Fastfile" ]; then
    echo "✅ Fastlane configured"
else
    echo "❌ Fastlane not configured"
fi

echo ""
echo "Next steps:"
echo "1. Push code to GitHub"
echo "2. Configure secrets in GitHub repository settings"
echo "3. Push a tag to trigger deployment"
```

Save as `check-cicd.sh` and run: `bash check-cicd.sh`
