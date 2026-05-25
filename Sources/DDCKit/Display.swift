import Foundation

/// A display's pixel resolution and its position in the desktop arrangement.
///
/// `originX`/`originY` are the top-left corner in the global coordinate space,
/// so the display with the smallest `originX` is the leftmost screen.
public struct DisplayGeometry: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let originX: Int
    public let originY: Int

    public init(width: Int, height: Int, originX: Int, originY: Int) {
        self.width = width
        self.height = height
        self.originX = originX
        self.originY = originY
    }
}

/// A controllable external display.
///
/// `Display` is the public, hardware-facing API of the engine. It pairs an
/// identity (id, name, optional EDID) with an `I2CTransport`, and turns
/// high-level reads and writes into DDC/CI exchanges — handling the protocol's
/// inter-command delay and the retries that flaky monitors require.
public final class Display {

    /// 1-based index, stable for the lifetime of an enumeration.
    public let id: Int
    /// Human-readable name (from the OS or EDID, with a generic fallback).
    public let name: String
    /// Parsed EDID, when one could be read for this display.
    public let edid: EDID?
    /// Resolution and desktop position, when known.
    public let geometry: DisplayGeometry?

    private let transport: I2CTransport
    private let interCommandDelay: TimeInterval
    private let maxRetries: Int

    public init(id: Int,
                name: String,
                edid: EDID? = nil,
                geometry: DisplayGeometry? = nil,
                transport: I2CTransport,
                interCommandDelay: TimeInterval = 0.05,
                maxRetries: Int = 3) {
        self.id = id
        self.name = name
        self.edid = edid
        self.geometry = geometry
        self.transport = transport
        self.interCommandDelay = interCommandDelay
        self.maxRetries = maxRetries
    }

    /// Sets a VCP feature. DDC/CI set requests are fire-and-forget — the
    /// monitor sends no reply.
    public func setVCP(_ code: VCPCode, value: UInt16) throws {
        try transport.write(DDCMessage.setVCP(code, value: value))
    }

    /// Reads a VCP feature, retrying transient failures.
    ///
    /// `featureUnsupported` is permanent and is thrown immediately; checksum,
    /// malformed-reply, and communication errors are retried up to
    /// `maxRetries` times.
    public func getVCP(_ code: VCPCode) throws -> VCPReading {
        let request = DDCMessage.getVCPRequest(code)
        var lastError: Error = DDCError.malformedReply
        for attempt in 0..<max(1, maxRetries) {
            if attempt > 0 { sleepBetweenCommands() }
            do {
                try transport.write(request)
                sleepBetweenCommands()
                let reply = try transport.read(length: DDCMessage.replyLength)
                return try DDCMessage.parseGetReply(reply, expecting: code)
            } catch DDCError.featureUnsupported(let code) {
                throw DDCError.featureUnsupported(code)
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// Probes whether this display can be driven over DDC/CI.
    ///
    /// Returns `false` for monitors that don't carry DDC — most commonly those
    /// on a Mac's built-in HDMI port. A reply of "feature unsupported" still
    /// counts as responsive: the channel works, the monitor simply declined.
    public func respondsToDDC() -> Bool {
        do {
            _ = try getVCP(.brightness)
            return true
        } catch DDCError.featureUnsupported {
            return true
        } catch {
            return false
        }
    }

    private func sleepBetweenCommands() {
        guard interCommandDelay > 0 else { return }
        Thread.sleep(forTimeInterval: interCommandDelay)
    }
}
