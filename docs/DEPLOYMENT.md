# Deployment Pipeline

Cards ships with GitHub Actions driving plain `xcodebuild` and the scripts in `scripts/`. A push to `main` only runs CI. Nothing is uploaded to App Store Connect until a version is tagged. `docs/DEVELOPMENT.md` section 8 and the release skill (`.claude/skills/release/SKILL.md`) give the release steps in order.

## Workflows

| Workflow | Runs on | What it does |
|----------|---------|--------------|
| `ci.yml` (CI) | Every push, to any branch, and every pull request | On Linux, the metadata, changelog and translation checks and the scripts' tests; on `xcode-27`, the release check; and a job for each test run in `scripts/lib/test-devices.ts`: the unit tests on the iPhone 17 on iOS 27.0, and the UI tests on the iPhone 17 and the iPad mini on iOS 26.5 and, on `macos-26` with Xcode 26.6, the iPhone 16 on iOS 18.6. No App Store image check (`release.yml` has it), no screenshots and no SwiftLint, which runs locally before a commit. A newer push cancels an older run |
| `release.yml` (Release to App Store) | `v*` tags, on `xcode-27` | Checks every App Store image is present (`scripts/check-store-images.ts`), installs signing, then runs `scripts/release-version.ts`: it checks the tag, stamps a build number, archives and signs (`scripts/build-ipa.ts`), uploads (`scripts/upload-build.ts`), attaches the build to the version, sets What's New from the tag message and submits for review (`scripts/submit-for-review.ts`). Run by hand, it uploads without submitting |
| `app-store-listing.yml` (App Store listing) | By hand | Gives the editable version its number with **prepare version**, then uploads the text in `metadata/`, the images in `screenshots/store/` and each locale's creative asset (the product page header and search results image). It does not upload or attach builds |
| `website.yml` (Deploy Website) | Pushes to `main` that change anything the site is built from (the listing, the changelog, the store images, the app's catalogue, colours or project, `Website/` or its scripts), or by hand | Deploys nothing, with a notice, while an App Store image is missing (`scripts/check-store-images.ts`); otherwise builds the site into `Website/dist` (`scripts/build-website.ts`), which stops it while a source is broken, then deploys it to Cloudflare Pages (`scripts/deploy-website.ts`). One deploy runs at a time, in push order |

The macOS jobs run on GitHub's `xcode-27` image and select the Xcode named in `.xcode-version` with `scripts/select-xcode.ts`, the same one local builds use, and stop if the image lacks it. CI runs on every push and pull request: the metadata, changelog and translation checks and the script tests, the release check, and a job for each test run in `scripts/lib/test-devices.ts` (`scripts/print-test-runs.ts` lists them for the matrix, `scripts/run-tests.ts --run <key>` runs one): the unit tests on the iPhone 17 on iOS 27.0, and the UI tests on the iPhone 17 and the iPad mini on iOS 26.5 and the iPhone 16 on iOS 18.6. The image has only iOS 27 runtimes, so a run downloads its iOS from Apple (about 8.5 GB for 26.5) while the app builds. The iOS 18 job is the exception: Xcode 27 cannot download iOS 18, so it runs on the `macos-26` image with Xcode 26.6 (`select-xcode.ts --run ui-iphone-18`), which downloads iOS 18.6. CI does not check the App Store images: `release.yml` does, before it builds anything.

There is no TestFlight workflow. To put a build on TestFlight, run `make upload-build` locally with an App Store Connect API key in the environment.

## Scripts

Every script is TypeScript, run with `node scripts/<name>.ts` (`docs/DEVELOPMENT.md`, rule 14). Those the pipelines use:

- `scripts/select-xcode.ts`: prints the Developer directory of the Xcode in `.xcode-version`, for `DEVELOPER_DIR`.
- `scripts/print-test-runs.ts` and `scripts/run-tests.ts`: CI's test matrix, and one test run: installs its iOS runtime if it is missing and boots its simulator while the app and tests build, then runs the unit or UI tests on it.
- `scripts/check-release-build.ts`, `scripts/check-metadata.ts`, `scripts/check-changelog.ts` and `scripts/check-strings.ts`: CI's checks. `scripts/check-store-images.ts`: the release's, and the website's before it deploys.
- `scripts/install-signing-certificate.ts` and `scripts/install-signing-profiles.ts` (run by `.github/actions/install-signing`): import the distribution certificate into a temporary keychain, and install an App Store profile for each bundle ID, creating it when it is missing or invalid. `install-signing-certificate.ts --remove` deletes the keychain afterwards.
- `scripts/release-version.ts`: the release, from tag to submission, using `scripts/build-ipa.ts` (archive and export a signed `.ipa`, taking `BUILD_NUMBER`, `CARDS_APP_PROFILE` and `CARDS_WIDGET_PROFILE`), `scripts/upload-build.ts` (upload it with `xcrun altool`) and `scripts/submit-for-review.ts` (wait for processing, attach, set What's New and submit; `--dry-run` only reads).
- `scripts/prepare-app-store-version.ts`, `scripts/upload-metadata.ts`, `scripts/upload-screenshots.ts` and `scripts/upload-creative-assets.ts`: the listing workflow's steps, which also run locally.
- `scripts/build-website.ts` and `scripts/deploy-website.ts`: the website's build and deploy.

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
   git tag -a v1.3 -F <(node scripts/print-release-notes.ts 1.3)
   git push origin v1.3
   ```
4. `release.yml` uploads the build and submits it for review. Watch it through to the end.

## Local commands

```bash
make build              # build for the simulator
make test               # unit and UI tests
make check              # the quick checks CI runs, plus the raw screenshot check
make upload-build       # archive and upload to App Store Connect, for TestFlight (needs ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_CONTENT)
```

## Troubleshooting

- **Signing:** check the distribution certificate has not expired, and look at the `install-signing-profiles.ts` output in the release log for the profile it installed.
- **Upload rejected as a duplicate:** each upload needs a new build number. The release job stamps one from the time, so rerun it rather than reusing an old archive.
- **Submission fails on the build:** `submit-for-review.ts` waits for the build of the tag's version to finish processing. If Apple is slow, rerun the workflow from the Actions tab.
