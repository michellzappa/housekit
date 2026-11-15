import Foundation

/// A parsed `CHANGELOG.md`. Apps bundle the file so About works offline.
/// Ported from Headroom.
public struct ChangelogDocument: Equatable, Sendable {
    public var versions: [ChangelogVersion]

    public init(versions: [ChangelogVersion]) {
        self.versions = versions
    }
}

public struct ChangelogVersion: Equatable, Identifiable, Sendable {
    /// The marketing version, e.g. "0.5.1". "Unreleased" is kept as written.
    public var version: String
    /// The date text from the heading, e.g. "2026-11-15". Nil when the heading has no date.
    public var date: String?
    public var sections: [ChangelogSection]

    public var id: String { version }

    public init(version: String, date: String? = nil, sections: [ChangelogSection] = []) {
        self.version = version
        self.date = date
        self.sections = sections
    }

    /// "0.5.1 · 15 Nov 2026". No em dash: the house copy rule.
    public var title: String {
        guard let date, !date.isEmpty else { return version }
        return "\(version) · \(Changelog.displayDate(date))"
    }
}

public struct ChangelogSection: Equatable, Sendable {
    /// "Added", "Fixed"… Empty for bullets directly under a version heading.
    public var title: String
    public var items: [String]

    public init(title: String, items: [String]) {
        self.title = title
        self.items = items
    }
}

public enum Changelog {
    /// `CHANGELOG.md` in the app bundle. Nil when the file is missing.
    public static func load(from bundle: Bundle = .main) -> ChangelogDocument? {
        guard let url = bundle.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        return parse(text)
    }

    /// Turns Keep a Changelog markdown into version blocks.
    ///
    /// Version headings are `## X.Y.Z — date`, `## X.Y.Z – date`,
    /// `## X.Y.Z - date`, `## [X.Y.Z] - date` or `## X.Y.Z`. Text above the
    /// first version heading is release process, not notes, and is dropped.
    /// Soft-wrapped bullet lines are joined into one item.
    public static func parse(_ markdown: String) -> ChangelogDocument {
        var versions: [ChangelogVersion] = []
        var current: ChangelogVersion?
        var section: ChangelogSection?
        var pendingItem: String?

        func flushItem() {
            guard let item = pendingItem?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            pendingItem = nil
            guard !item.isEmpty else { return }
            if section == nil { section = ChangelogSection(title: "", items: []) }
            section?.items.append(item)
        }

        func flushSection() {
            flushItem()
            if let done = section, !done.items.isEmpty || !done.title.isEmpty {
                current?.sections.append(done)
            }
            section = nil
        }

        func flushVersion() {
            flushSection()
            if let done = current, !done.version.isEmpty { versions.append(done) }
            current = nil
        }

        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("## ") {
                flushVersion()
                let (version, date) = heading(String(trimmed.dropFirst(3)))
                current = ChangelogVersion(version: version, date: date)
                continue
            }

            guard current != nil else { continue }

            if trimmed.hasPrefix("### ") {
                flushSection()
                section = ChangelogSection(
                    title: trimmed.dropFirst(4).trimmingCharacters(in: .whitespaces),
                    items: []
                )
                continue
            }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushItem()
                pendingItem = String(trimmed.dropFirst(2))
                continue
            }

            if trimmed.isEmpty {
                flushItem()
                continue
            }

            if let open = pendingItem {
                pendingItem = open + " " + trimmed
            } else {
                // Prose under a version with no bullet: keep it as one item.
                pendingItem = trimmed
            }
        }

        flushVersion()
        return ChangelogDocument(versions: versions)
    }

    /// Splits "0.5.1 — 2026-11-15" into version and date. The plain hyphen
    /// counts only with a space on each side, so an ISO date is never cut.
    static func heading(_ text: String) -> (version: String, date: String?) {
        let text = text.trimmingCharacters(in: .whitespaces)
        for separator in ["—", "–", " - "] {
            if let range = text.range(of: separator) {
                let version = cleanVersion(String(text[..<range.lowerBound]))
                let date = text[range.upperBound...].trimmingCharacters(in: .whitespaces)
                return (version, date.isEmpty ? nil : date)
            }
        }
        return (cleanVersion(text), nil)
    }

    private static func cleanVersion(_ text: String) -> String {
        var version = text.trimmingCharacters(in: .whitespaces)
        if version.hasPrefix("["), version.hasSuffix("]") {
            version = String(version.dropFirst().dropLast())
        }
        return version
    }

    /// "2026-11-15" → "15 Nov 2026". Other text is returned as written.
    /// English month names on purpose: the rest of the copy is English, and
    /// the output must not change with the Mac's locale.
    public static func displayDate(_ text: String) -> String {
        let parts = text.split(separator: "-")
        guard parts.count == 3, parts[0].count == 4,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day)
        else { return text }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(day) \(months[month - 1]) \(year)"
    }
}
