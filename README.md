# HouseKit

The bits Tessellate, Cargo and Strata share so they read as one family.

- `Glyph` / `HouseGlyphs` — each app's mark, in normalized field coordinates. One
  definition renders both the 18pt menu bar icon and the 1024px app icon.
- `MenuBarPlate` — the dark gradient plate with hairline rim; drop-in for the
  file that used to be copied between apps. `MenuBarPlate.image(glyph:)`.
- `IconPlate` — the same plate at Apple's 824-of-1024 footprint; writes iconsets / `.icns`.
- `LaunchAtLogin`, `BuildInfo` — the three-liners every app had.
- `housekit-icon` — CLI the build scripts call: `housekit-icon strata AppIcon.icns`.

Add to an app as a local package (`path: ../housekit` in `project.yml`, or
`.package(path: "../housekit")` in `Package.swift`).
