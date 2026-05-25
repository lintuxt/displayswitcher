import Foundation

/// A parsed EDID (Extended Display Identification Data) block.
///
/// EDID gives a display a stable identity — used to label monitors in the CLI
/// and (later) the UI. Only the first 128-byte base block is parsed; that is
/// where the manufacturer, product, serial, and descriptor strings live.
public struct EDID: Equatable, Sendable {
    /// Three-letter manufacturer code, e.g. "DEL".
    public let manufacturerID: String
    /// Manufacturer-assigned product code.
    public let productCode: UInt16
    /// 32-bit serial number (0 if the display does not provide one).
    public let serialNumber: UInt32
    /// Human-readable model name from the 0xFC descriptor, if present.
    public let displayName: String?
    /// Serial-number string from the 0xFF descriptor, if present.
    public let serialText: String?

    private static let header: [UInt8] = [0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00]

    /// Parses a 128-byte EDID base block. Returns nil if the buffer is too
    /// short, has a bad header, or fails its checksum.
    public init?(_ bytes: [UInt8]) {
        guard bytes.count >= 128 else { return nil }
        guard Array(bytes.prefix(8)) == EDID.header else { return nil }

        var checksum: UInt8 = 0
        for byte in bytes.prefix(128) { checksum = checksum &+ byte }
        guard checksum == 0 else { return nil }

        manufacturerID = EDID.decodeManufacturer(bytes[8], bytes[9])
        productCode = UInt16(bytes[10]) | UInt16(bytes[11]) << 8
        serialNumber = UInt32(bytes[12])
            | UInt32(bytes[13]) << 8
            | UInt32(bytes[14]) << 16
            | UInt32(bytes[15]) << 24

        var name: String?
        var serial: String?
        // Four 18-byte descriptors begin at offset 54.
        for offset in stride(from: 54, to: 54 + 4 * 18, by: 18) {
            // A display descriptor (vs. a timing block) starts 00 00 00.
            guard bytes[offset] == 0, bytes[offset + 1] == 0, bytes[offset + 2] == 0 else { continue }
            let tag = bytes[offset + 3]
            let text = EDID.decodeDescriptorText(Array(bytes[(offset + 5)..<(offset + 18)]))
            switch tag {
            case 0xFC: name = text
            case 0xFF: serial = text
            default: break
            }
        }
        displayName = name
        serialText = serial
    }

    /// Decodes the packed 5-bits-per-letter manufacturer ID (big-endian).
    private static func decodeManufacturer(_ high: UInt8, _ low: UInt8) -> String {
        let packed = UInt16(high) << 8 | UInt16(low)
        let letters = [
            (packed >> 10) & 0x1F,
            (packed >> 5) & 0x1F,
            packed & 0x1F,
        ]
        let scalars = letters.compactMap { value -> Character? in
            guard (1...26).contains(value) else { return nil }
            return Character(UnicodeScalar(UInt8(value) + 64)) // 1 -> 'A'
        }
        return String(scalars)
    }

    /// Decodes a descriptor text field: ASCII terminated by 0x0A, space-padded.
    private static func decodeDescriptorText(_ bytes: [UInt8]) -> String {
        let trimmed = bytes.prefix { $0 != 0x0A }
        let string = String(decoding: trimmed, as: UTF8.self)
        return string.trimmingCharacters(in: .whitespaces)
    }
}
