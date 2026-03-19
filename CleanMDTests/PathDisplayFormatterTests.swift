import XCTest
@testable import CleanMD

final class PathDisplayFormatterTests: XCTestCase {
    func testParentPathDropsFileName() {
        let formatter = PathDisplayFormatter(homeDirectory: URL(fileURLWithPath: "/Users/test"))
        let url = URL(fileURLWithPath: "/Users/test/projects/demo/config.yaml")

        XCTAssertEqual(formatter.parentPath(for: url), "~/projects/demo")
    }

    func testParentPathUsesHomeTildeWhenParentIsHomeDirectory() {
        let formatter = PathDisplayFormatter(homeDirectory: URL(fileURLWithPath: "/Users/test"))
        let url = URL(fileURLWithPath: "/Users/test/config.yaml")

        XCTAssertEqual(formatter.parentPath(for: url), "~")
    }

    func testParentPathKeepsNonHomeAbsolutePaths() {
        let formatter = PathDisplayFormatter(homeDirectory: URL(fileURLWithPath: "/Users/test"))
        let url = URL(fileURLWithPath: "/tmp/work/config.yaml")

        XCTAssertEqual(formatter.parentPath(for: url), "/tmp/work")
    }
}
