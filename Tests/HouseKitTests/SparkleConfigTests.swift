import Foundation
import Testing
@testable import HouseKitSparkle

@Suite struct SparkleConfigTests {
    @Test func aTestBundleHasNoFeed() {
        // The test runner is not an app: no SUFeedURL, so Sparkle stays off.
        #expect(SparkleConfig(bundle: .main).isComplete == false)
    }

    @Test @MainActor func updaterStaysOffWithoutAFeed() {
        let updater = SparkleUpdater(appName: "Test")
        #expect(updater.canInstall == false)
        #expect(updater.automaticChecks == false)
        #expect(updater.lastError != nil)
    }
}
