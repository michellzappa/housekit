@testable import HouseKit
import Testing

@Suite struct ChangelogTests {
    @Test func parsesEmDashEnDashAndHyphenHeadings() {
        let document = Changelog.parse("""
        # Changelog

        Release process text that is not a note.

        ## 0.5.2 — 2026-11-15

        ### Fixed

        - One fix.

        ## 0.5.1 - 2026-11-14

        - Plain bullet.

        ## 0.5.0 – 2026-11-01

        - En dash.

        ## [0.4.0] - 2026-10-01

        - Brackets.

        ## 0.3.0

        - No date.
        """)
        #expect(document.versions.map(\.version) == ["0.5.2", "0.5.1", "0.5.0", "0.4.0", "0.3.0"])
        #expect(document.versions.map(\.date) == ["2026-11-15", "2026-11-14", "2026-11-01", "2026-10-01", nil])
        #expect(document.versions[0].sections == [ChangelogSection(title: "Fixed", items: ["One fix."])])
        #expect(document.versions[1].sections == [ChangelogSection(title: "", items: ["Plain bullet."])])
    }

    @Test func hyphenInsideVersionIsNotASeparator() {
        let (version, date) = Changelog.heading("1.0.0-beta.2 - 2026-11-15")
        #expect(version == "1.0.0-beta.2")
        #expect(date == "2026-11-15")
        #expect(Changelog.heading("1.0.0-beta.2").date == nil)
    }

    @Test func joinsSoftWrappedBullets() {
        let document = Changelog.parse("""
        ## 1.0.0 — 2026-01-02

        ### Added

        - **Bold start.** The sentence goes on
          over a second line.
        * Star bullet.

        ### Changed

        Prose with no bullet.
        """)
        let sections = document.versions[0].sections
        #expect(sections.count == 2)
        #expect(sections[0].items == ["**Bold start.** The sentence goes on over a second line.", "Star bullet."])
        #expect(sections[1] == ChangelogSection(title: "Changed", items: ["Prose with no bullet."]))
    }

    @Test func emptyAndPreambleOnlyGiveNoVersions() {
        #expect(Changelog.parse("").versions.isEmpty)
        #expect(Changelog.parse("# Changelog\n\nNothing yet.").versions.isEmpty)
    }

    @Test func titleUsesMiddleDotAndShortDate() {
        #expect(ChangelogVersion(version: "0.5.1", date: "2026-11-15").title == "0.5.1 · 15 Nov 2026")
        #expect(ChangelogVersion(version: "2.0.0", date: "2026-01-05").title == "2.0.0 · 5 Jan 2026")
        #expect(ChangelogVersion(version: "0.3.0").title == "0.3.0")
        #expect(ChangelogVersion(version: "Unreleased", date: "soon").title == "Unreleased · soon")
        #expect(!ChangelogVersion(version: "0.5.1", date: "2026-11-15").title.contains("—"))
    }

    @Test func displayDateKeepsNonISOText() {
        #expect(Changelog.displayDate("2026-13-01") == "2026-13-01")
        #expect(Changelog.displayDate("15 Nov 2026") == "15 Nov 2026")
        #expect(Changelog.displayDate("2026-12-31") == "31 Dec 2026")
    }
}

@Suite struct VersionLabelTests {
    @Test func menuLabel() {
        #expect(BuildInfo.label(version: "1.2", build: "34") == "v1.2 (34)")
        #expect(BuildInfo.label(version: "1.2", build: nil) == "development build")
        #expect(BuildInfo.label(version: nil, build: "34") == "development build")
    }

    @Test func aboutLabel() {
        #expect(BuildInfo.aboutLabel(version: "0.5.1", build: "120") == "Version 0.5.1 (120)")
        #expect(BuildInfo.aboutLabel(version: "0.5.1", build: nil) == "Version 0.5.1")
        #expect(BuildInfo.aboutLabel(version: nil, build: nil) == "Development build")
    }
}
