import XCTest
@testable import DDCKit

final class DisplayTests: XCTestCase {

    /// A display backed by a simulated monitor (no inter-command delay so
    /// tests run fast).
    private func makeDisplay(_ transport: MockTransport) -> Display {
        Display(id: 1, name: "Mock Monitor", transport: transport,
                interCommandDelay: 0, maxRetries: 3)
    }

    func testSetThenGetRoundTrip() throws {
        let monitor = MockTransport(features: [
            .brightness: VCPReading(current: 50, maximum: 100),
        ])
        let display = makeDisplay(monitor)

        try display.setVCP(.brightness, value: 80)
        let reading = try display.getVCP(.brightness)

        XCTAssertEqual(reading.current, 80)
        XCTAssertEqual(reading.maximum, 100)
    }

    func testGetRetriesOnTransientFailure() throws {
        let monitor = MockTransport(features: [
            .contrast: VCPReading(current: 42, maximum: 100),
        ])
        monitor.failNextReads = 2
        let display = makeDisplay(monitor)

        let reading = try display.getVCP(.contrast)

        XCTAssertEqual(reading.current, 42)
        XCTAssertEqual(monitor.readCount, 3) // 2 failures + 1 success
    }

    func testGetThrowsAfterExhaustingRetries() {
        let monitor = MockTransport(features: [
            .contrast: VCPReading(current: 42, maximum: 100),
        ])
        monitor.failNextReads = 99
        let display = makeDisplay(monitor)

        XCTAssertThrowsError(try display.getVCP(.contrast))
    }

    func testGetDoesNotRetryUnsupportedFeature() {
        // Monitor exposes no features at all.
        let monitor = MockTransport(features: [:])
        let display = makeDisplay(monitor)

        XCTAssertThrowsError(try display.getVCP(.brightness)) {
            XCTAssertEqual($0 as? DDCError, .featureUnsupported(.brightness))
        }
        XCTAssertEqual(monitor.readCount, 1) // permanent error — not retried
    }

    func testRespondsToDDCWhenMonitorReplies() {
        let display = makeDisplay(MockTransport(features: [
            .brightness: VCPReading(current: 50, maximum: 100),
        ]))
        XCTAssertTrue(display.respondsToDDC())
    }

    func testRespondsToDDCWhenFeatureUnsupported() {
        // The DDC channel works; the monitor just doesn't expose brightness.
        let display = makeDisplay(MockTransport(features: [:]))
        XCTAssertTrue(display.respondsToDDC())
    }

    func testDoesNotRespondToDDCWhenReadsFail() {
        let monitor = MockTransport(features: [
            .brightness: VCPReading(current: 50, maximum: 100),
        ])
        monitor.failNextReads = 999
        let display = makeDisplay(monitor)
        XCTAssertFalse(display.respondsToDDC())
    }
}
