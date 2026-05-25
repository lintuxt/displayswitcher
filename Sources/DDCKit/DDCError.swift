import Foundation

/// Errors surfaced by the DDC/CI engine.
public enum DDCError: Error, Equatable, Sendable {
    /// A DDC/CI reply failed its checksum.
    case checksumMismatch
    /// A reply had an unexpected length or structure.
    case malformedReply
    /// The monitor reported it does not support the requested feature.
    case featureUnsupported(VCPCode)
    /// A reply echoed a different VCP code than the one requested.
    case unexpectedFeature(expected: VCPCode, got: UInt8)
    /// An I2C read/write failed; carries the underlying IOReturn code.
    case communicationFailed(code: Int32)
    /// The private IOAVService API is unavailable on this system.
    case ioavServiceUnavailable
    /// No display matched the requested identifier.
    case displayNotFound
}

extension DDCError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .checksumMismatch:
            return "DDC/CI reply failed checksum validation."
        case .malformedReply:
            return "DDC/CI reply was malformed."
        case .featureUnsupported(let code):
            return "The monitor does not support \(code.name)."
        case .unexpectedFeature(let expected, let got):
            return "Expected a reply for \(expected.name) but got code 0x\(String(got, radix: 16))."
        case .communicationFailed(let code):
            return "I2C communication failed (IOReturn 0x\(String(format: "%08x", code)))."
        case .ioavServiceUnavailable:
            return "Monitor control is unavailable: the IOAVService API did not load."
        case .displayNotFound:
            return "No matching display was found."
        }
    }
}
