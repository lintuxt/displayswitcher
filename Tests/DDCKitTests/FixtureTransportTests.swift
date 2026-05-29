import XCTest
@testable import DDCKit

final class FixtureTransportTests: XCTestCase {
    func testReplyDecodesToCannedReading() throws {
        let readings: [VCPCode: VCPReading] = [
            .brightness: VCPReading(current: 25, maximum: 100),
        ]
        let transport = FixtureTransport(readings: readings)
        try transport.write(DDCMessage.getVCPRequest(.brightness))
        let reply = try transport.read(length: DDCMessage.replyLength)
        let parsed = try DDCMessage.parseGetReply(reply, expecting: .brightness)
        XCTAssertEqual(parsed, VCPReading(current: 25, maximum: 100))
    }

    func testUnknownCodeThrowsUnsupported() throws {
        let transport = FixtureTransport(readings: [:])
        try transport.write(DDCMessage.getVCPRequest(.contrast))
        let reply = try transport.read(length: DDCMessage.replyLength)
        XCTAssertThrowsError(
            try DDCMessage.parseGetReply(reply, expecting: .contrast))
    }
}
