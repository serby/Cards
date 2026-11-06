# Deployment Pipeline

Cards ships with GitHub Actions driving plain `xcodebuild` and the scripts in `scripts/`. A push to `main` only runs CI. Nothing is uploaded to App Store Connect until a version is tagged. `docs/DEVELOPMENT.md` section 8 and the release skill (`.claude/skills/release/SKILL.md`) give the release steps in order.

## Workflows

| Workflow | Runs on | What it does |
|----------|---------|--------------|
| `ci.yml` (CI) | Every push to `main` and every pull request, on `xcode-27` | Three jobs in parallel: the build and the unit tests; the release check; and, on Linux, the check that every App Store image is present plus the metadata and changelog checks. It captures no screenshots and runs no UI tests or SwiftLint: those run locally before a commit. A newer push cancels an older run, and pushes that only change docs, the spec or the website skip CI |
| `release.yml` (Release to App Store) | `v*` tags, on `xcode-27` | Installs signing, then runs `scripts/release-version.ts`: it checks the tag, stamps a build number, archives and signs (`scripts/build-ipa.ts`), uploads (`scripts/upload-build.ts`), attaches the build to the version, sets What's New from the tag message and submits for review (`scripts/submit-for-review.ts`). Run by hand, it uploads without submitting |
| `app-store-listing.yml` (App Store listing) | By hand | Gives the editable version its number with **prepare version**, then uploads the text in `metadata/`, the images in `screenshots/store/` and each locale's creative asset (the product page header and search results image). It does not upload or attach builds |
| `website.yml` (Deploy Website) | Pushes to `main` that change `Website/src/`, or by hand | Deploys `Website/src/` to Cloudflare Pages (`scripts/deploy-website.ts`) |

Both macOS workflows run on GitHub's `xcode-27` image and select the Xcode named in `.xcode-version` with `scripts/select-xcode.ts`, the same one local builds use. They stop if the image lacks it. CI's unit tests (`scripts/run-unit-tests.ts`) use the newest iOS runtime that Xcode's SDK supports (`scripts/lib/simulator.ts`).

There is no TestFlight workflow. To put a build on TestFlight, run `make upload-build` locally with an App Store Connect API key in the environment.

## Scripts

Every script is TypeScript, run with `node scripts/<name>.ts` (`docs/DEVELOPMENT.md`, rule 14). Those the pipelines use:

- `scripts/select-xcode.ts`: prints the Developer directory of the Xcode in `.xcode-version`, for `DEVELOPER_DIR`.
- `scripts/run-unit-tests.ts`: boots a simulator while the app and tests build, then runs `CardsTests` on it.
- `scripts/check-release-build.ts`, `scripts/check-store-images.ts`, `scripts/check-metadata.ts` and `scripts/check-changelog.ts`: CI's checks.
- `scripts/install-signing-certificate.ts` and `scripts/install-signing-profiles.ts` (run by `.github/actions/install-signing`): import the distribution certificate into a temporary keychain, and install an App Store profile for each bundle ID, creating it when it is missing or invalid. `install-signing-certificate.ts --remove` deletes the keychain afterwards.
- `scripts/release-version.ts`: the release, from tag to submission, using `scripts/build-ipa.ts` (archive and export a signed `.ipa`, taking `BUILD_NUMBER`, `CARDS_APP_PROFILE` and `CARDS_WIDGET_PROFILE`), `scripts/upload-build.ts` (upload it with `xcrun altool`) and `scripts/submit-for-review.ts` (wait for processing, attach, set What's New and submit; `--dry-run` only reads).
- `scripts/prepare-app-store-version.ts`, `scripts/upload-metadata.ts`, `scripts/upload-screenshots.ts` and `scripts/upload-creative-assets.ts`: the listing workflow's steps, which also run locally.
- `scripts/deploy-website.ts`: the website deploy.

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
