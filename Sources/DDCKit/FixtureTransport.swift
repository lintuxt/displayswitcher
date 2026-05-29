import Foundation

/// An `I2CTransport` that returns canned DDC/CI replies instead of touching
/// hardware. Used by the hidden demo scene (see `DisplayManager`); never on a
/// real device path.
public final class FixtureTransport: I2CTransport {
    private let readings: [VCPCode: VCPReading]
    private var pendingCode: VCPCode?

    public init(readings: [VCPCode: VCPReading]) {
        self.readings = readings
    }

    public func write(_ frame: [UInt8]) throws {
        // getVCPRequest frame: [0x80|len, getVCPOpcode, code, checksum].
        guard frame.count >= 3 else { return }
        pendingCode = VCPCode(rawValue: frame[2])
    }

    public func read(length: Int) throws -> [UInt8] {
        let code = pendingCode
        let reading = code.flatMap { readings[$0] }
        return Self.reply(for: code, reading: reading)
    }

    /// Builds an 11-byte get-VCP reply. A nil reading yields a non-zero result
    /// code (feature unsupported), matching a monitor that declines a feature.
    static func reply(for code: VCPCode?, reading: VCPReading?) -> [UInt8] {
        let result: UInt8 = reading == nil ? 0x01 : 0x00
        let maxV = reading?.maximum ?? 0
        let curV = reading?.current ?? 0
        var bytes: [UInt8] = [
            0x6E, 0x88, 0x02, result, code?.rawValue ?? 0x00, 0x00,
            UInt8(maxV >> 8), UInt8(maxV & 0xFF),
            UInt8(curV >> 8), UInt8(curV & 0xFF),
        ]
        var checksum: UInt8 = 0x50
        for byte in bytes { checksum ^= byte }
        bytes.append(checksum)
        return bytes
    }
}
