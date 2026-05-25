/// A VCP (Virtual Control Panel) feature code — the unit of DDC/CI control.
///
/// Each case's raw value is the on-the-wire feature code from the MCCS
/// (Monitor Control Command Set) standard.
public enum VCPCode: UInt8, CaseIterable, Sendable {
    case brightness = 0x10
    case contrast = 0x12
    case inputSource = 0x60

    /// A short, lower-case name used by the CLI (`get brightness`, ...).
    public var name: String {
        switch self {
        case .brightness: return "brightness"
        case .contrast: return "contrast"
        case .inputSource: return "input"
        }
    }

    /// Parses a CLI control name (case-insensitive). Returns nil if unknown.
    public init?(name: String) {
        switch name.lowercased() {
        case "brightness": self = .brightness
        case "contrast": self = .contrast
        case "input", "input-source", "inputsource": self = .inputSource
        default: return nil
        }
    }
}

/// A monitor input source, as carried by VCP code `0x60`.
///
/// Raw values are the MCCS-defined input source codes.
public enum InputSource: UInt8, CaseIterable, Sendable {
    case vga = 0x01
    case dvi = 0x03
    case displayPort1 = 0x0F
    case displayPort2 = 0x10
    case hdmi1 = 0x11
    case hdmi2 = 0x12
    case usbC = 0x1B

    /// The canonical lower-case name (`hdmi1`, `dp1`, `usbc`, ...).
    public var name: String {
        switch self {
        case .vga: return "vga"
        case .dvi: return "dvi"
        case .displayPort1: return "dp1"
        case .displayPort2: return "dp2"
        case .hdmi1: return "hdmi1"
        case .hdmi2: return "hdmi2"
        case .usbC: return "usbc"
        }
    }

    /// Parses a friendly input-source name (case-insensitive). Returns nil if
    /// unrecognised. Accepts both `dp1` and `displayport1` style spellings.
    public init?(name: String) {
        switch name.lowercased() {
        case "vga": self = .vga
        case "dvi": self = .dvi
        case "dp1", "displayport1": self = .displayPort1
        case "dp2", "displayport2": self = .displayPort2
        case "hdmi1": self = .hdmi1
        case "hdmi2": self = .hdmi2
        case "usbc", "usb-c", "usb": self = .usbC
        default: return nil
        }
    }
}
