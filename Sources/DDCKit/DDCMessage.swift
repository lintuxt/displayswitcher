/// The result of reading a VCP feature: its current and maximum values.
public struct VCPReading: Equatable, Sendable {
    public let current: UInt16
    public let maximum: UInt16

    public init(current: UInt16, maximum: UInt16) {
        self.current = current
        self.maximum = maximum
    }
}

/// Builds and parses DDC/CI frames.
///
/// This type is pure logic — it never touches hardware. A frame produced here
/// is the payload buffer handed to `IOAVServiceWriteI2C`, with the I2C chip
/// address (`i2cChipAddress`) and source address (`i2cSourceAddress`) supplied
/// separately by the transport.
public enum DDCMessage {

    /// 7-bit I2C address of the display's DDC/CI channel.
    public static let i2cChipAddress: UInt32 = 0x37
    /// Source address byte, written ahead of the frame payload.
    public static let i2cSourceAddress: UInt32 = 0x51
    /// Number of bytes in a get-VCP reply.
    public static let replyLength = 11

    // DDC/CI checksum seeds.
    private static let displayWriteAddress: UInt8 = 0x6E
    private static let hostAddress: UInt8 = 0x51
    private static let replyChecksumSeed: UInt8 = 0x50

    // DDC/CI opcodes.
    private static let setVCPOpcode: UInt8 = 0x03
    private static let getVCPOpcode: UInt8 = 0x01

    /// Builds a "set VCP feature" frame for `code := value`.
    ///
    /// The set checksum seeds with the display address XOR the host address.
    public static func setVCP(_ code: VCPCode, value: UInt16) -> [UInt8] {
        let payload: [UInt8] = [
            setVCPOpcode, code.rawValue,
            UInt8(value >> 8), UInt8(value & 0xFF),
        ]
        return framed(payload, checksumSeed: displayWriteAddress ^ hostAddress)
    }

    /// Builds a "get VCP feature" request frame for `code`.
    ///
    /// Unlike the set frame, the get-request checksum seeds with the display
    /// address only — it does not include the host address. Real monitors
    /// reject the request otherwise (verified on hardware; matches m1ddc).
    public static func getVCPRequest(_ code: VCPCode) -> [UInt8] {
        framed([getVCPOpcode, code.rawValue], checksumSeed: displayWriteAddress)
    }

    /// Parses an 11-byte get-VCP reply, verifying its checksum, result code,
    /// and that it echoes the feature we asked for.
    public static func parseGetReply(_ bytes: [UInt8], expecting code: VCPCode) throws -> VCPReading {
        guard bytes.count == replyLength else { throw DDCError.malformedReply }

        var checksum = replyChecksumSeed
        for byte in bytes.dropLast() { checksum ^= byte }
        guard checksum == bytes[10] else { throw DDCError.checksumMismatch }

        // bytes[3] is the result code: 0 == success, non-zero == unsupported.
        guard bytes[3] == 0 else { throw DDCError.featureUnsupported(code) }

        // bytes[4] echoes the VCP code the reply describes.
        guard bytes[4] == code.rawValue else {
            throw DDCError.unexpectedFeature(expected: code, got: bytes[4])
        }

        let maximum = UInt16(bytes[6]) << 8 | UInt16(bytes[7])
        let current = UInt16(bytes[8]) << 8 | UInt16(bytes[9])
        return VCPReading(current: current, maximum: maximum)
    }

    /// Wraps a payload as `[lengthByte, payload..., checksum]`, where the
    /// trailing checksum is `checksumSeed` XOR'd with every frame byte.
    private static func framed(_ payload: [UInt8], checksumSeed: UInt8) -> [UInt8] {
        var frame: [UInt8] = [0x80 | UInt8(payload.count)]
        frame.append(contentsOf: payload)
        var checksum = checksumSeed
        for byte in frame { checksum ^= byte }
        frame.append(checksum)
        return frame
    }
}
