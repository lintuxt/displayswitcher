/// A bidirectional I2C channel to a single display's DDC/CI endpoint.
///
/// This is the seam between the pure DDC/CI logic and the platform. The
/// Apple Silicon implementation talks to `IOAVService`; `MockTransport`
/// simulates a monitor in memory. A future Linux/Windows port adds another
/// conformer without touching `Display` or `DDCMessage`.
public protocol I2CTransport: AnyObject {
    /// Writes a DDC/CI frame to the display's DDC channel.
    func write(_ frame: [UInt8]) throws

    /// Reads `length` bytes from the display's DDC channel.
    func read(length: Int) throws -> [UInt8]
}
