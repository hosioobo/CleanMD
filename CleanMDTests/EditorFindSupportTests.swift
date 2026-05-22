import AppKit
import XCTest
@testable import CleanMD

final class EditorFindSupportTests: XCTestCase {
    func testConfigureEnablesNativeFindSupport() {
        let textView = NSTextView()

        EditorFindSupport.configure(textView: textView)

        XCTAssertTrue(textView.usesFindBar)
        XCTAssertTrue(textView.isIncrementalSearchingEnabled)
    }
}
