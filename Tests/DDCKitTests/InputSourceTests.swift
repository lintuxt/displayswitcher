import XCTest
@testable import DDCKit

final class InputSourceTests: XCTestCase {
    func testParsesFriendlyNamesCaseInsensitively() {
        XCTAssertEqual(InputSource(name: "hdmi1"), .hdmi1)
        XCTAssertEqual(InputSource(name: "HDMI1"), .hdmi1)
        XCTAssertEqual(InputSource(name: "hdmi2"), .hdmi2)
        XCTAssertEqual(InputSource(name: "dp1"), .displayPort1)
        XCTAssertEqual(InputSource(name: "displayport1"), .displayPort1)
        XCTAssertEqual(InputSource(name: "usbc"), .usbC)
    }

    func testUnknownNameReturnsNil() {
        XCTAssertNil(InputSource(name: "banana"))
    }
}
