import XCTest
@testable import CleanMD

final class ColorSettingsTests: XCTestCase {
    func testRestoreDefaultsResetsPalettesAndDividerFlags() {
        let suiteName = "ColorSettingsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = ColorSettings(defaults: defaults)
        settings.lightPalette = ColorPalette(editorBg: "#111111")
        settings.darkPalette = ColorPalette(editorBg: "#222222")
        settings.showH1Divider = false
        settings.showH2Divider = false

        settings.restoreDefaults()

        XCTAssertEqual(settings.lightPalette, .lightDefault)
        XCTAssertEqual(settings.darkPalette, .darkDefault)
        XCTAssertTrue(settings.showH1Divider)
        XCTAssertTrue(settings.showH2Divider)
    }

    func testFlushPendingPersistWritesDebouncedChangesImmediately() {
        let suiteName = "ColorSettingsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create isolated defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = ColorSettings(
            defaults: defaults,
            persistDelay: 60,
            notificationCenter: .init(),
            observeTermination: false
        )
        settings.lightPalette.editorBg = "#123456"

        XCTAssertNil(defaults.string(forKey: "cp_v2_light"))

        settings.flushPendingPersist()

        XCTAssertNotNil(defaults.string(forKey: "cp_v2_light"))
    }
}
