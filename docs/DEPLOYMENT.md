# Deployment Pipeline

Cards ships with GitHub Actions driving plain `xcodebuild` and the scripts in `scripts/`. A push to `main` only runs CI. Nothing is uploaded to App Store Connect until a version is tagged. `docs/DEVELOPMENT.md` section 8 and the release skill (`.claude/skills/release/SKILL.md`) give the release steps in order.

## Workflows

| Workflow | Runs on | What it does |
|----------|---------|--------------|
| `ci.yml` (CI) | Every push to `main` and every pull request, on `macos-26` | The build, the metadata and changelog checks, the release check, the tests, and checks on the checked-in and freshly captured screenshots. It does not run SwiftLint, so lint locally |
| `release.yml` (Release to App Store) | `v*` tags, on `macos-26` | Stamps a build number, archives and signs (`scripts/build-ipa.sh`), uploads (`scripts/deploy-appstore.sh`), then attaches the build to the version, sets What's New from the tag message and submits for review (`scripts/asc-submit.sh`) |
| `app-store-listing.yml` (App Store listing) | By hand | Gives the editable version its number with **prepare version**, then uploads the text in `metadata/` and the images in `screenshots/store/`. It does not upload or attach builds |
| `website.yml` (Deploy Website) | Pushes to `main` that change `Website/src/`, or by hand | Deploys the website to Cloudflare |
| `export-asc-creds.yml` | By hand | One-off credential export. It writes the App Store Connect key to a downloadable artifact in a public repository, so do not run it, and delete it |

There is no TestFlight workflow. To put a build on TestFlight, run `make deploy-testflight` locally with an App Store Connect API key in the environment.

## Scripts

- `scripts/build-ipa.sh`: archives in Release and exports a signed `.ipa`. It takes the build number from `BUILD_NUMBER` and the profiles from `CARDS_APP_PROFILE` and `CARDS_WIDGET_PROFILE`.
- `scripts/deploy-appstore.sh`: builds with `build-ipa.sh` and uploads with `xcrun altool`. `make deploy-appstore` runs it.
- `scripts/deploy-testflight.sh`: the same, for TestFlight. `make deploy-testflight` runs it. It is for manual use only.
- `scripts/asc-submit.sh`: waits for the upload to process, finds or creates the App Store version, attaches the build, sets What's New and submits for review.
- `scripts/asc-version.ts`, `scripts/upload-metadata.ts` and `scripts/upload-screenshots.ts`: the listing workflow's steps, which also run locally.
- `scripts/asc-profiles.ts` (run by `.github/actions/install-signing`): installs an App Store profile for each bundle ID, creating it when it is missing or invalid.

## Secrets

Set these in the repository's Settings > Secrets and variables > Actions:

- `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_CONTENT`: the App Store Connect API key, used by the release and listing workflows.
- `BUILD_CERTIFICATE_BASE64` and `P12_PASSWORD`: the Apple Distribution certificate as a base64 `.p12`, and its password.
- `KEYCHAIN_PASSWORD`: a password for the temporary keychain the release job creates.
- `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN`: for the website.

CI keeps no provisioning profiles. `docs/CICD_SETUP.md` covers creating the certificate and the API key.

## Release flow

1. Push to `main` and wait for CI to pass.
2. Run the App Store listing workflow with **prepare version** to number the version and upload its text and images. Do a dry run first.
3. Tag the release with its notes and push the tag:
   ```bash
   git tag -a v1.3 -F <(node scripts/changelog.ts notes 1.3)
   git push origin v1.3
   ```
4. `release.yml` uploads the build and submits it for review. Watch it through to the end.

## Local commands

```bash
make build               # build for the simulator
make test                # unit and UI tests
make deploy-testflight   # archive and upload to TestFlight (needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT)
make deploy-appstore     # archive and upload to App Store Connect
```

## Troubleshooting

- **Signing:** check the distribution certificate has not expired, and look at the `asc-profiles.ts` output in the release log for the profile it installed.
- **Upload rejected as a duplicate:** each upload needs a new build number. The release job stamps one from the time, so rerun it rather than reusing an old archive.
- **Submission fails on the build:** `asc-submit.sh` waits for the build of the tag's version to finish processing. If Apple is slow, rerun the workflow from the Actions tab.
