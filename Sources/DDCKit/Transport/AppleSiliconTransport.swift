import Foundation
import IOKit
import CIOAVService

/// I2C transport for Apple Silicon Macs.
///
/// Wraps Apple's private `IOAVService`, reached through the `CIOAVService`
/// C shim. This is the one piece of the engine that cannot run without real
/// hardware — it is verified manually through the CLI rather than unit tests.
/// Every platform detail is contained here, behind the `I2CTransport` seam.
final class AppleSiliconTransport: I2CTransport {

    /// The underlying `IOAVService` (a CF object; ARC releases it on deinit).
    private let service: CFTypeRef

    /// Creates a transport for one display's IORegistry service node.
    init(ioService: io_service_t) throws {
        guard ds_ioav_available() != 0 else {
            throw DDCError.ioavServiceUnavailable
        }
        guard let avService = ds_ioav_create(ioService) else {
            throw DDCError.communicationFailed(code: KERN_FAILURE)
        }
        self.service = avService
    }

    func write(_ frame: [UInt8]) throws {
        var buffer = frame
        let status = buffer.withUnsafeMutableBytes { raw -> Int32 in
            ds_ioav_write(service,
                          DDCMessage.i2cChipAddress,
                          DDCMessage.i2cSourceAddress,
                          raw.baseAddress, UInt32(raw.count))
        }
        AppleSiliconTransport.trace("write", frame, status: status)
        guard status == 0 else { throw DDCError.communicationFailed(code: status) }
    }

    func read(length: Int) throws -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: length)
        let status = buffer.withUnsafeMutableBytes { raw -> Int32 in
            ds_ioav_read(service,
                         DDCMessage.i2cChipAddress,
                         DDCMessage.i2cSourceAddress,
                         raw.baseAddress, UInt32(raw.count))
        }
        AppleSiliconTransport.trace("read ", buffer, status: status)
        guard status == 0 else { throw DDCError.communicationFailed(code: status) }
        return buffer
    }

    /// Opt-in I2C tracing, enabled by setting the `DS_DEBUG` environment
    /// variable. Off by default with zero overhead.
    private static let debugEnabled = ProcessInfo.processInfo.environment["DS_DEBUG"] != nil

    private static func trace(_ label: String, _ bytes: [UInt8], status: Int32) {
        guard debugEnabled else { return }
        let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        let line = "[DS_DEBUG] \(label) [\(hex)] status=\(String(format: "0x%08X", status))\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}
