import XCTest
@testable import CleanMD

final class ColorHexTests: XCTestCase {
    func testNormalizeAcceptsBareSixDigitHex() {
        XCTAssertEqual(ColorHex.normalize("ABCDEF"), "#abcdef")
    }

    func testNormalizeTrimsWhitespaceAndKeepsLeadingHash() {
        XCTAssertEqual(ColorHex.normalize("  #1A2b3C  "), "#1a2b3c")
    }

    func testNormalizeRejectsInvalidHex() {
        XCTAssertNil(ColorHex.normalize("#12345"))
        XCTAssertNil(ColorHex.normalize("#12GG34"))
    }
}
