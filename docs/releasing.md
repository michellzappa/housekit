# Releasing a Mac app

One release definition for every Mac app: [`release-mac.yml`](../.github/workflows/release-mac.yml),
a reusable workflow. Each app keeps a short `release.yml` that calls it.
Decision (Michell, 2026-11-17): **Sparkle is the one updater for all Mac apps.**
The exception is Headroom; see `docs/updater.md` in that repo.

## What a release does

1. Builds a universal app (`xcodegen generate`, then `xcodebuild archive`)
   with Developer ID, hardened runtime and a secure timestamp.
   `CFBundleVersion` is the commit count, so it grows with every release.
2. Signs Sparkle's helpers inside the app with the same identity.
3. Checks the app: the version matches the tag, `SUFeedURL` and
   `SUPublicEDKey` are present, the signature verifies.
4. Takes the release notes from the app's `CHANGELOG.md` section for the
   version. No section, no release.
5. Notarizes, staples, and checks Gatekeeper.
6. Zips `<App>-<version>.zip`, writes `SHA256SUMS`, attests provenance.
7. Signs the zip with the app's Sparkle EdDSA key and checks the signature
   against the public key inside the app. A mismatch fails the run.
8. Writes `appcast.xml` (one item; the notes as HTML) and publishes the zip,
   `SHA256SUMS` and `appcast.xml` as one GitHub Release, marked latest.

Nothing is published before step 8, so a red run leaves every app on the
last version that exists.

## The feed

Each app's feed is the appcast on its own latest release:

    https://github.com/michellzappa/<repo>/releases/latest/download/appcast.xml

GitHub redirects that URL to the newest release's asset. There is no feed
host to run, no cross-repo push and no second credential.

Why not `updates.centaur-labs.io`: that host is the GitHub Pages site of the
Headroom repo (`docs/` on `main`). A custom domain serves one Pages site, so
Septena's appcast there never went live (`/appcast.xml` answers 503), and
putting fifteen apps on it needs a token that can push to one repo from all
of them, plus moving Headroom's live `latest.json`. To move a feed later,
ship one release whose `SUFeedURL` names the new one; copies update to it
from the old feed first.

## Add an app

1. **Info.plist**

       <key>CFBundleVersion</key>
       <string>$(CURRENT_PROJECT_VERSION)</string>
       <key>SUFeedURL</key>
       <string>https://github.com/michellzappa/<repo>/releases/latest/download/appcast.xml</string>
       <key>SUPublicEDKey</key>
       <string><from sparkle-key.sh></string>
       <key>SUEnableAutomaticChecks</key>
       <true/>

   A sandboxed app also needs `SUEnableInstallerLauncherService` and
   `SUEnableDownloaderService` set to true, and these entitlements:

       com.apple.security.temporary-exception.mach-lookup.global-name
         $(PRODUCT_BUNDLE_IDENTIFIER)-spks
         $(PRODUCT_BUNDLE_IDENTIFIER)-spki

2. **project.yml**: depend on the `HouseKitSparkle` product of the
   `HouseKit` package, and create one `SparkleUpdater()`. Pass it to
   `StatusMenu.appendStandardTail(updates:)` for "Check for Updates…" and to
   `GeneralSettingsPane(updates:)` for the Updates section.

3. **Key pair**, once per app:

       ./scripts/sparkle-key.sh michellzappa/<repo>

   It keeps the private key in the login keychain and the repo's
   `SPARKLE_PRIVATE_ED_KEY` secret, and prints the public key for step 1.

4. **Apple secrets** (Developer ID certificate, App Store Connect API key):

       ./scripts/setup-release-secrets.sh --p12 … --api-key … --api-key-id … --api-issuer-id … michellzappa/<repo>

5. **`.github/workflows/release.yml`** in the app:

   ```yaml
   name: Release

   on:
     push:
       tags: ["v*"]
     workflow_dispatch:
       inputs:
         publish:
           description: Tag v<version> from main and publish it
           type: boolean
           default: false

   permissions:
     contents: write
     id-token: write
     attestations: write

   jobs:
     release:
       uses: michellzappa/housekit/.github/workflows/release-mac.yml@main
       with:
         app-name: Tessellate
         siblings: michellzappa/housekit
         publish: ${{ github.event_name == 'push' || inputs.publish }}
       secrets:
         APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
         APPLE_DEVELOPER_CERTIFICATE_P12_BASE64: ${{ secrets.APPLE_DEVELOPER_CERTIFICATE_P12_BASE64 }}
         APPLE_DEVELOPER_CERTIFICATE_PASSWORD: ${{ secrets.APPLE_DEVELOPER_CERTIFICATE_PASSWORD }}
         APPLE_API_KEY_ID: ${{ secrets.APPLE_API_KEY_ID }}
         APPLE_API_ISSUER_ID: ${{ secrets.APPLE_API_ISSUER_ID }}
         APPLE_API_PRIVATE_KEY_BASE64: ${{ secrets.APPLE_API_PRIVATE_KEY_BASE64 }}
         SPARKLE_PRIVATE_ED_KEY: ${{ secrets.SPARKLE_PRIVATE_ED_KEY }}
   ```

   An app with a restricted entitlement (iCloud) also passes
   `MACOS_PROVISION_PROFILE`, the base64 Developer ID provisioning profile.
   Without it the run fails: such an app notarizes and then does not launch.

   Other inputs: `scheme`, `project`, `runner` (default `macos-26`),
   `submodules`, `xcodegen`, `build-number-command`, `xcodebuild-args`,
   `verify-command` (runs with `APP_PATH` set to the signed app).

## Cut a release

Bump the version, add its `## X.Y.Z - YYYY-MM-DD` section to `CHANGELOG.md`,
merge to `main`, then either push the tag `vX.Y.Z` or run:

    gh workflow run release.yml -R michellzappa/<repo> -f publish=true

The run tags `main` as `v<version>`. It refuses a version that already has a
release. `publish=false` builds, notarizes and signs without publishing and
keeps the zip and appcast as a run artifact for seven days.

Callers use `@main`, so a change to `release-mac.yml` reaches every app's
next release. Run one app with `publish=false` after changing it.
