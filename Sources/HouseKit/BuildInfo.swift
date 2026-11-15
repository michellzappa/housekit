import Foundation

public enum BuildInfo {
    /// The marketing version from the bundle, e.g. "1.2". Nil when unstamped.
    public static var version: String? { stamp("CFBundleShortVersionString") }

    /// The build number from the bundle, e.g. "34". Nil when unstamped.
    public static var build: String? { stamp("CFBundleVersion") }

    /// "v1.2 (34)" from the bundle, or "development build" when unstamped.
    public static var label: String { label(version: version, build: build) }

    /// "Version 1.2 (34)" for the About pane, or "Development build" when unstamped.
    public static var aboutLabel: String { aboutLabel(version: version, build: build) }

    /// "v1.2 (34)". Both parts are necessary; without them the result is "development build".
    public static func label(version: String?, build: String?) -> String {
        guard let version, let build else { return "development build" }
        return "v\(version) (\(build))"
    }

    /// "Version 1.2 (34)", or "Version 1.2" when the build number is missing.
    /// Without a version the result is "Development build".
    public static func aboutLabel(version: String?, build: String?) -> String {
        guard let version else { return "Development build" }
        guard let build else { return "Version \(version)" }
        return "Version \(version) (\(build))"
    }

    private static func stamp(_ key: String) -> String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespaces)
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
