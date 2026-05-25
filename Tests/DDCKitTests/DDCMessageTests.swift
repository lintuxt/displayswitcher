import XCTest
@testable import DDCKit

final class DDCMessageTests: XCTestCase {

    // MARK: Building requests

    func testSetVCPBuildsFrameWithChecksum() {
        // brightness (0x10) := 75 (0x004B)
        // [length, set-opcode, code, valueHi, valueLo, checksum]
        // checksum = 0x6E ^ 0x51 ^ 0x84 ^ 0x03 ^ 0x10 ^ 0x00 ^ 0x4B = 0xE3
        let frame = DDCMessage.setVCP(.brightness, value: 75)
        XCTAssertEqual(frame, [0x84, 0x03, 0x10, 0x00, 0x4B, 0xE3])
    }

    func testSetVCPEncodes16BitValues() {
        // value 300 = 0x012C -> hi 0x01, lo 0x2C
        let frame = DDCMessage.setVCP(.inputSource, value: 300)
        XCTAssertEqual(frame[0...4], [0x84, 0x03, 0x60, 0x01, 0x2C])
        XCTAssertEqual(frame.count, 6)
    }

    func testGetVCPRequestBuildsFrameWithChecksum() {
        // The get-request checksum seeds with the display address ONLY — unlike
        // the set frame it does not include the host/source address 0x51.
        // (Verified against real hardware and the m1ddc reference.)
        // checksum = 0x6E ^ 0x82 ^ 0x01 ^ 0x10 = 0xFD
        let frame = DDCMessage.getVCPRequest(.brightness)
        XCTAssertEqual(frame, [0x82, 0x01, 0x10, 0xFD])
    }

    // MARK: Parsing replies

    /// A well-formed get-VCP reply: brightness, current 75, max 100.
    private func validBrightnessReply() -> [UInt8] {
        var reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x4B]
        var checksum: UInt8 = 0x50
        for byte in reply { checksum ^= byte }
        reply.append(checksum)
        return reply
    }

    func testParseGetReplyExtractsCurrentAndMaximum() throws {
        let reading = try DDCMessage.parseGetReply(validBrightnessReply(), expecting: .brightness)
        XCTAssertEqual(reading.current, 75)
        XCTAssertEqual(reading.maximum, 100)
    }

    func testParseGetReplyRejectsBadChecksum() {
        var reply = validBrightnessReply()
        reply[reply.count - 1] ^= 0xFF
        XCTAssertThrowsError(try DDCMessage.parseGetReply(reply, expecting: .brightness)) {
            XCTAssertEqual($0 as? DDCError, .checksumMismatch)
        }
    }

    func testParseGetReplyRejectsWrongLength() {
        XCTAssertThrowsError(try DDCMessage.parseGetReply([0x6E, 0x88], expecting: .brightness)) {
            XCTAssertEqual($0 as? DDCError, .malformedReply)
        }
    }

    func testParseGetReplyRejectsUnsupportedFeature() {
        // result code byte (index 3) = 0x01 means "unsupported VCP code"
        var reply: [UInt8] = [0x6E, 0x88, 0x02, 0x01, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00]
        var checksum: UInt8 = 0x50
        for byte in reply { checksum ^= byte }
        reply.append(checksum)
        XCTAssertThrowsError(try DDCMessage.parseGetReply(reply, expecting: .brightness)) {
            XCTAssertEqual($0 as? DDCError, .featureUnsupported(.brightness))
        }
    }

    func testParseGetReplyRejectsMismatchedFeature() {
        // reply echoes code 0x12 (contrast) but we asked for brightness
        var reply: [UInt8] = [0x6E, 0x88, 0x02, 0x00, 0x12, 0x00, 0x00, 0x64, 0x00, 0x4B]
        var checksum: UInt8 = 0x50
        for byte in reply { checksum ^= byte }
        reply.append(checksum)
        XCTAssertThrowsError(try DDCMessage.parseGetReply(reply, expecting: .brightness)) {
            XCTAssertEqual($0 as? DDCError, .unexpectedFeature(expected: .brightness, got: 0x12))
        }
    }
}
