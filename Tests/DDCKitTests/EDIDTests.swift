import XCTest
@testable import DDCKit

final class EDIDTests: XCTestCase {

    /// Builds a valid 128-byte EDID block with a fixed-up checksum.
    /// - manufacturer "DEL", product 0xA0C9, serial 0x01020304
    /// - descriptor 1: monitor name "DELL U2719D"
    /// - descriptor 2: serial text "ABC123"
    private func sampleEDID() -> [UInt8] {
        var edid = [UInt8](repeating: 0, count: 128)
        edid[0...7] = [0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]

        // Manufacturer "DEL" packed big-endian: D=4, E=5, L=12.
        edid[8] = 0x10
        edid[9] = 0xAC
        // Product code 0xA0C9, little-endian.
        edid[10] = 0xC9
        edid[11] = 0xA0
        // Serial number 0x01020304, little-endian.
        edid[12] = 0x04
        edid[13] = 0x03
        edid[14] = 0x02
        edid[15] = 0x01

        func writeDescriptor(at offset: Int, tag: UInt8, text: String) {
            edid[offset] = 0
            edid[offset + 1] = 0
            edid[offset + 2] = 0
            edid[offset + 3] = tag
            edid[offset + 4] = 0
            var data = Array(text.utf8)
            data.append(0x0A) // line feed terminator
            while data.count < 13 { data.append(0x20) } // space padded
            for (i, byte) in data.prefix(13).enumerated() {
                edid[offset + 5 + i] = byte
            }
        }
        writeDescriptor(at: 54, tag: 0xFC, text: "DELL U2719D")
        writeDescriptor(at: 72, tag: 0xFF, text: "ABC123")

        // Checksum: the 128 bytes must sum to 0 mod 256.
        var sum: UInt8 = 0
        for byte in edid.prefix(127) { sum = sum &+ byte }
        edid[127] = UInt8((256 - Int(sum)) % 256)
        return edid
    }

    func testParsesManufacturerAndProductCode() {
        let edid = EDID(sampleEDID())
        XCTAssertEqual(edid?.manufacturerID, "DEL")
        XCTAssertEqual(edid?.productCode, 0xA0C9)
    }

    func testParsesSerialNumber() {
        let edid = EDID(sampleEDID())
        XCTAssertEqual(edid?.serialNumber, 0x01020304)
    }

    func testParsesDisplayNameAndSerialText() {
        let edid = EDID(sampleEDID())
        XCTAssertEqual(edid?.displayName, "DELL U2719D")
        XCTAssertEqual(edid?.serialText, "ABC123")
    }

    func testRejectsInvalidHeader() {
        var bytes = sampleEDID()
        bytes[0] = 0x42
        XCTAssertNil(EDID(bytes))
    }

    func testRejectsBadChecksum() {
        var bytes = sampleEDID()
        bytes[127] = bytes[127] &+ 1
        XCTAssertNil(EDID(bytes))
    }

    func testRejectsShortBuffer() {
        XCTAssertNil(EDID([0x00, 0xFF, 0xFF]))
    }
}
