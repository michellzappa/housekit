# HouseKit

The bits Tessellate, Cargo and Clip share so they read as one family. Local
SPM package; each app depends on it by path (`../housekit`).

## What is in it

**Look**
- `Glyph` / `HouseGlyphs` — each app's mark, in normalized field coordinates.
  One definition renders both the 18pt menu bar icon and the 1024px app icon.
- `MenuBarPlate` — the dark gradient plate with hairline rim. `MenuBarPlate.image(glyph:)`.
- `IconPlate` — the same plate at Apple's 824-of-1024 footprint; writes iconsets / `.icns`.
- `housekit-icon` — CLI the build scripts call: `housekit-icon clip AppIcon.icns`.

**Chrome**
- `StatusMenu` — `sectionHeader(_:)` and `appendStandardTail(...)`: Settings… ⌘, ·
  Launch at Login ✓ · Quit <App> ⌘Q, identical in every app.
- `SettingsWindowController` — "<App> Settings": source-list sidebar, one page per
  entry, `<App>.Settings` frame autosave. Convention: app pages first, then
  `GeneralPage`, then `AboutPage`.
- `SettingsForm` — a page: two-column grid (label | control), `section`, `row`,
  `toggle`, `note`, small-control factories (`button`, `textField`, `popup`,
  `stepper`, `status`). Controls save on change; no Save buttons.
- `GeneralPage` — launch at login, show menu bar icon, live permission rows
  (`PermissionRow.accessibility`), plus app extras.
- `AboutPage` — icon, name, version, executable path (the Accessibility grant
  binds to one exact binary), links.

**Plumbing**
- `LaunchAtLogin` (`SMAppService`), `BuildInfo.label` ("v1.2 (34)").

## Conventions the apps follow

- xcodegen `project.yml`, Swift 6, macOS 14, strict concurrency, manual signing
  with the stable Apple Development identity (TCC and Keychain key their grants
  to the signature). Bundle id `app.<name>.<Name>`.
- `scripts/build-app.sh`: regenerate icon → xcodegen → xcodebuild (unsigned) →
  codesign → `/Applications/<App>.app`. Same file in every repo.
- `NSStatusItem`, menu rebuilt in `menuWillOpen`, `LSUIElement`.
- Settings opens from ⌘, in the status menu and on app reopen.
- README shape: principle → how it works → requirements → install + signing
  note → configuration → architecture table → limitations.

## Adding an app

1. Add a `Glyph` to `HouseGlyphs.all`.
2. Copy Clip's `project.yml`, `scripts/build-app.sh`, `Resources/`, and
   `.github/workflows/release.yml`; rename.
3. Build the status menu with `StatusMenu`, the settings window with
   `SettingsWindowController` + your `SettingsForm` pages + `GeneralPage` + `AboutPage`.

```sh
swift build && swift test
```
