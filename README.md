# HouseKit

The bits mz's Mac apps (Headroom, Sift, Tessellate, Cargo, Clip, Lift) share so
they read as one family. Local SPM package; each app depends on it by path
(`../housekit`).

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

**Settings (house style, SwiftUI)** — the Headroom shape.
- `HouseSettingsView(appName:panes:)` — `NavigationSplitView`: fixed 220 pt
  sidebar, grouped `Form` detail, 820 × 600, window title "<App> Settings",
  floats above other windows. Use it in a SwiftUI `Settings` scene.
- `HouseSettingsWindowController(appName:panes:)` — the same view in its own
  window for AppKit menu-bar apps. `show(pane:)` selects a pane by id.
- `SettingsPane(id:title:symbol:) { … }` — one sidebar row. Shortcuts:
  `.general { … }` (id `general`) and `.about { … }` (id `about`).
- `SettingsLeaf` + `SettingsLeafLink` — push a page on top of a pane. The shell
  draws its own Back button in the title bar and drops the leaf when the
  sidebar selection changes. `SettingsNavigation` holds selection and leaf.
- `GeneralSettingsPane` — Startup (launch at login with the Login Items
  approval case, optional menu bar icon), live Permissions rows
  (`PermissionRow`), optional Updates, then app `extras` sections.
- `UpdatesSection` + `UpdateChecking` — this version, latest, automatic
  switch, Check Now, Update to X. Each app keeps its own feed and installer and
  adds a conformance; the checker must be `@Observable`.
- `AboutSettingsPane` — icon (`AboutAppIcon` asset, else the app icon), name,
  "Version 0.5.1 (120)", tagline, credit, Changelog sheet, Source on GitHub
  with live stars (`repository: "owner/name"`), more `AboutLink`s, optional
  executable path (`showsExecutable: true` for apps that need Accessibility).
- `Changelog.parse` / `Changelog.load()` — bundled `CHANGELOG.md`. Headings
  `## X.Y.Z — date`, `## X.Y.Z - date`, `## [X.Y.Z] - date`. Titles render
  "0.5.1 · 15 Nov 2026" (no em dash).
- `ChangelogView`, `ChangelogWindow.show(appName:)` — the notes as a sheet or
  as a window for a "What's New…" menu item.

**Settings (deprecated, AppKit)** — keep working until every app has moved.
Do not use them in new code.
- `SettingsWindowController`, `SettingsPage`, `SettingsForm`, `GeneralPage`,
  `AboutPage`.
- Migration: replace `SettingsWindowController(appName:pages:)` with
  `HouseSettingsWindowController(appName:panes:)`. Put General first and About
  last. Rebuild each `SettingsForm` page as a SwiftUI `Form` of `Section`s in a
  `SettingsPane`. `GeneralPage(launchAtLogin:showMenuBarIcon:permissions:extras:)`
  becomes `GeneralSettingsPane` with `Binding`s; `AboutPage(appName:tagline:links:)`
  becomes `AboutSettingsPane(appName:tagline:repository:links:)`. The frame
  autosave name stays `<App>.Settings`.

**Plumbing**
- `LaunchAtLogin` (`SMAppService`: `isEnabled`, `isRequested`, `needsApproval`,
  `openLoginItemsSettings()`), `BuildInfo.label` ("v1.2 (34)"),
  `BuildInfo.aboutLabel` ("Version 1.2 (34)").

## Conventions the apps follow

- xcodegen `project.yml`, Swift 6, macOS 14, strict concurrency, manual signing
  with the stable Apple Development identity (TCC and Keychain key their grants
  to the signature). Bundle id `app.<name>.<Name>`.
- `scripts/build-app.sh`: regenerate icon → xcodegen → xcodebuild (unsigned) →
  codesign → `/Applications/<App>.app`. Same file in every repo.
- `NSStatusItem`, menu rebuilt in `menuWillOpen`, `LSUIElement`.
- Settings opens from ⌘, in the status menu and on app reopen.
- Settings is the SwiftUI shell: General first, app panes, About last. Controls
  save on change; no Save buttons. Each pane is a grouped `Form` of `Section`s
  with footers for explanations.
- `CHANGELOG.md` at the repo root, bundled as a resource, headings
  `## X.Y.Z - YYYY-MM-DD`. About opens it.
- README shape: principle → how it works → requirements → install + signing
  note → configuration → architecture table → limitations.

## Adding an app

1. Add a `Glyph` to `HouseGlyphs.all`.
2. Copy Clip's `project.yml`, `scripts/build-app.sh`, `Resources/`, and
   `.github/workflows/release.yml`; rename.
3. Build the status menu with `StatusMenu`.
4. Build settings with `HouseSettingsWindowController` (AppKit app) or
   `Settings { HouseSettingsView(...) }` (SwiftUI app): `.general { GeneralSettingsPane(...) }`,
   your `SettingsPane`s, `.about { AboutSettingsPane(...) }`.
5. Add `CHANGELOG.md` and list it under the target's resources in `project.yml`.
   Add an `AboutAppIcon` image set if the app is `LSUIElement`.

```sh
swift build && swift test
```
