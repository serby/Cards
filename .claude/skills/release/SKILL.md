---
name: release
description: The standard way to mark changes to Card Barcodes and release them. Use it when a change Paul has agreed to ship needs recording, when asked to mark changes, update the changelog or What's New, or to release, ship or submit a version to the App Store. It writes changelog.json entries from the commits, regenerates CHANGELOG.md and the App Store release notes, keeps spec/ in step, bumps the version, and runs the release.
---

# Release: mark changes and ship versions

`changelog.json` at the repository root is the single record of what changed for the people using the app. `node scripts/generate-changelog.ts` turns it into `CHANGELOG.md` and each locale's `metadata/<locale>/release_notes.txt` (the App Store's What's New), and the app bundles it for Settings > What's New. CI runs `node scripts/check-changelog.ts`, which fails if a generated file is stale or if the newest version in the changelog is not the app's `MARKETING_VERSION`. `spec/` holds the user stories for the whole app.

Read `AGENTS.md` and `docs/DEVELOPMENT.md` first. Rule 11 applies: a change Paul needs to see is only marked and pushed once he has agreed it ships.

## Mark changes

Run this whenever an agreed change is about to be pushed, or when asked to mark changes.

1. **Find what changed.** List the commits since `changelog.json` last changed: `git log --format='%h %s' $(git log -1 --format=%H -- changelog.json)..HEAD`. Include any commits you are about to make. Read the bodies (`git show`) of anything that may be user-facing.
2. **Pick the version.** If the newest version in `changelog.json` has `"date": null`, it is in preparation: add to it. If it has a date, it is released, so this change starts the next version. Bump the project-level `MARKETING_VERSION` in `Cards.xcodeproj/project.pbxproj` (both configurations; minor for features, eg 1.3 to 1.4, patch for fixes only, eg 1.3 to 1.3.1) and add a new version at the top with `"date": null`. App Store Connect refuses builds of a version it has already approved, so the bump is not optional.
3. **Write the entries.** Add only changes people notice: new things they can do (`new`), things that work better (`improved`), and problems that no longer happen (`fixed`). Leave out tests, CI, refactors and docs unless the person using the app would notice. Merge related commits into one entry and update an existing entry rather than adding a near duplicate.
   - **Wording:** one short sentence each, saying what the person can do or what changed: "Give each card a colour from 23, or pick any colour you like."
   - **Spelling:** `text` is British English. Add `"en-US"` only where American English differs (colour/color, till/checkout, postcode/ZIP code).
   - **Voice:** Paul's, as [docs/LANGUAGE.md](../../../docs/LANGUAGE.md) sets out. Plain and active, no hype, no exclamation marks, "it is" and "that is" in full, no em-dashes, never "land" for shipping, and no real brand names.
4. **Update the spec.** For each change, update the matching stories in `spec/`, or add new ones with an ID, acceptance criteria and "Since:" the version. Keep `spec/README.md`'s index current.
5. **Generate and check:** `node scripts/generate-changelog.ts`, then `node scripts/check-changelog.ts` and `node scripts/check-metadata.ts`.
6. **Commit** the changelog, generated files and spec together as `docs(changelog): <what>`. Commit the version bump separately as `chore: version <x.y>`, explaining why.

## Release a version

Ask Paul before submitting: it publishes to the App Store and cannot be taken back once approved.

1. **Agree the scope.** Show Paul the version's entries (`node scripts/print-release-notes.ts <version>`) and the screens that changed, and get his go-ahead.
2. **Finish marking:** run "Mark changes" so nothing since the last entry is missing.
3. **Date it:** set the version's `date` to today, then `generate`. The date is the day it is released on the App Store, which normally follows approval within a day or two. If Apple releases it on a different day, correct the date the next time you mark changes.
4. **Settle the spec:** change any "In preparation for <version>" stories to "Since: <version>".
5. **Screenshots:** if any screen the App Store shows has changed, run `make capture-screenshots`, then `make store-screenshots`, and look at every changed image. The capture takes six screens on each device, including the card with its share menu open (`06_ShareCard`, shown by `05_Share`), and `make check-screenshots` must pass with nothing reported as not captured yet. `make store-screenshots` also composes each locale's universal creative asset (`screenshots/store/<locale>/CreativeAsset.png`, 5244 × 2950) from its `creative-asset.json` and the new card screen capture: look at it whole, and check the line and the barcode sit inside the safe area that the Storybook's StoreCreativeAsset story outlines. If a caption or the asset's line changed, check every locale's translation fits.
6. **Validate:** run the loop in `docs/DEVELOPMENT.md` section 2, plus `node scripts/check-changelog.ts` and `node scripts/check-metadata.ts`. Commit, push, and wait for CI to pass.
7. **Prepare the listing:** run the App Store listing workflow. Do a dry run first, then for real:

   ```bash
   gh workflow run app-store-listing.yml -f version=<version> -f prepare-version=true -f dry-run=true
   gh workflow run app-store-listing.yml -f version=<version> -f prepare-version=true
   ```

   The dry run must report every age rating question answered, and for each locale the creative asset's specification and the header and search results placements it would make. After the real run, open the version in App Store Connect and check the header and search results in its preview, on iPhone and iPad in both orientations, with the line and the barcode in view.
8. **Tag and submit:**

   ```bash
   git tag -a v<version> -F <(node scripts/print-release-notes.ts <version>)
   git push origin v<version>
   ```

   `release.yml` builds, uploads, attaches the build, sets What's New from the tag and submits it for review. Watch it through to the end and report the result.
