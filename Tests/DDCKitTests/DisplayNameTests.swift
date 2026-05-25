import XCTest
@testable import DDCKit

final class DisplayNameTests: XCTestCase {
    func testStripsMacOSDeduplicationSuffix() {
        XCTAssertEqual(strippedDisplayName("DELL U2715H (3)"), "DELL U2715H")
        XCTAssertEqual(strippedDisplayName("LG HDR 4K (12)"), "LG HDR 4K")
    }

    func testLeavesPlainNamesUnchanged() {
        XCTAssertEqual(strippedDisplayName("DELL U2715H"), "DELL U2715H")
        XCTAssertEqual(strippedDisplayName("Studio Display"), "Studio Display")
    }

    func testLeavesNonNumericParentheticalsUnchanged() {
        XCTAssertEqual(strippedDisplayName("Acme (Pro)"), "Acme (Pro)")
        XCTAssertEqual(strippedDisplayName("Weird ()"), "Weird ()")
    }
}
