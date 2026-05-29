import XCTest
@testable import DDCKit

final class DemoModeTests: XCTestCase {
    func testDemoEnvYieldsThreeFixtureDisplays() throws {
        setenv("LINTUXT_DEBUG", "1", 1)
        defer { unsetenv("LINTUXT_DEBUG") }

        let displays = try DisplayManager.displays()
        XCTAssertEqual(displays.count, 3)
        XCTAssertEqual(displays.map(\.id), [1, 2, 3])
        XCTAssertTrue(displays.allSatisfy { $0.name == "DELL U2715H" })

        // id 2 left, id 1 centre, id 3 right
        func x(_ id: Int) -> Int { displays.first { $0.id == id }!.geometry!.originX }
        XCTAssertLessThan(x(2), x(1))
        XCTAssertLessThan(x(1), x(3))

        let one = displays.first { $0.id == 1 }!
        XCTAssertEqual(try one.getVCP(.brightness), VCPReading(current: 25, maximum: 100))
        XCTAssertEqual(try one.getVCP(.contrast), VCPReading(current: 50, maximum: 100))
        XCTAssertEqual(try one.getVCP(.inputSource).current, UInt16(InputSource.hdmi1.rawValue))
    }
}
