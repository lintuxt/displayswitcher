/// An in-memory monitor simulator.
///
/// `MockTransport` plays the role of a real display's DDC firmware: it stores
/// VCP feature values, answers get-requests with well-formed DDC/CI replies,
/// and can be told to fail a number of reads to exercise retry handling. It
/// makes the whole engine testable without hardware.
public final class MockTransport: I2CTransport {

    private struct Feature {
        var current: UInt16
        var maximum: UInt16
    }

    /// Features the simulated monitor supports, keyed by VCP code.
    private var features: [UInt8: Feature]
    /// The VCP code from the most recent get-request.
    private var pendingGetCode: UInt8?

    /// Number of writes received, for assertions.
    public private(set) var writeCount = 0
    /// Number of reads received, for assertions.
    public private(set) var readCount = 0
    /// The next N reads will throw a communication failure before succeeding.
    public var failNextReads = 0

    public init(features: [VCPCode: VCPReading]) {
        var stored: [UInt8: Feature] = [:]
        for (code, reading) in features {
            stored[code.rawValue] = Feature(current: reading.current, maximum: reading.maximum)
        }
        self.features = stored
    }

    public func write(_ frame: [UInt8]) throws {
        writeCount += 1
        guard frame.count >= 3 else { throw DDCError.malformedReply }
        let opcode = frame[1]
        let code = frame[2]
        switch opcode {
        case 0x03 where frame.count >= 5: // set VCP feature
            let value = UInt16(frame[3]) << 8 | UInt16(frame[4])
            features[code]?.current = value
        case 0x01: // get VCP feature request
            pendingGetCode = code
        default:
            break
        }
    }

    public func read(length: Int) throws -> [UInt8] {
        readCount += 1
        if failNextReads > 0 {
            failNextReads -= 1
            throw DDCError.communicationFailed(code: -1)
        }
        guard let code = pendingGetCode else { throw DDCError.malformedReply }
        if let feature = features[code] {
            return MockTransport.reply(code: code, resultCode: 0,
                                       current: feature.current, maximum: feature.maximum)
        }
        // Unknown feature: result code 1 == "unsupported VCP code".
        return MockTransport.reply(code: code, resultCode: 1, current: 0, maximum: 0)
    }

    /// Builds an 11-byte get-VCP reply with a valid DDC/CI checksum.
    private static func reply(code: UInt8, resultCode: UInt8,
                              current: UInt16, maximum: UInt16) -> [UInt8] {
        var bytes: [UInt8] = [
            0x6E, 0x88, 0x02, resultCode, code, 0x00,
            UInt8(maximum >> 8), UInt8(maximum & 0xFF),
            UInt8(current >> 8), UInt8(current & 0xFF),
        ]
        var checksum: UInt8 = 0x50
        for byte in bytes { checksum ^= byte }
        bytes.append(checksum)
        return bytes
    }
}
