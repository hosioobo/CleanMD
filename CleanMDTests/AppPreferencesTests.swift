import XCTest
@testable import CleanMD

final class AppPreferencesTests: XCTestCase {
    func testScrollSyncPreferenceDefaultsLinked() {
        let suiteName = "AppPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertTrue(AppPreferences.scrollSyncIsLinked(defaults: defaults))
    }

    func testScrollSyncPreferenceReadsStoredValue() {
        let suiteName = "AppPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(false, forKey: AppPreferenceKeys.isScrollSyncLinked)

        XCTAssertFalse(AppPreferences.scrollSyncIsLinked(defaults: defaults))
    }
}
