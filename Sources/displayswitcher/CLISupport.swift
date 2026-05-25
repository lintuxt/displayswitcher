import ArgumentParser
import CLIKit
import DDCKit

/// An error whose message is printed to the user verbatim.
struct CLIError: Error, CustomStringConvertible {
    let description: String
}

/// Which display(s) a command targets: one by number, or every display.
enum DisplaySelector: ExpressibleByArgument, CustomStringConvertible {
    case one(Int)
    case all

    init?(argument: String) {
        if argument.lowercased() == "all" {
            self = .all
        } else if let number = Int(argument), number > 0 {
            self = .one(number)
        } else {
            return nil
        }
    }

    var description: String {
        switch self {
        case .all: return "all"
        case .one(let number): return "\(number)"
        }
    }
}

/// Resolves a selector to the displays it targets, sorted by number.
func targets(for selector: DisplaySelector) throws -> [Display] {
    let displays = try DisplayManager.displays().sorted { $0.id < $1.id }
    guard !displays.isEmpty else {
        throw CLIError(description: "No external displays found.")
    }
    switch selector {
    case .all:
        return displays
    case .one(let number):
        guard let match = displays.first(where: { $0.id == number }) else {
            let available = displays.map { String($0.id) }.joined(separator: ", ")
            throw CLIError(description: "No display \(number). Available displays: \(available).")
        }
        return [match]
    }
}

/// A clear, terminal error for a display that can't be driven over DDC/CI.
func uncontrollableError(_ display: Display) -> CLIError {
    CLIError(description: """
        \(display.name) (display \(display.id)) can't be controlled — it does not \
        respond to DDC/CI.
        This usually means it's connected through the Mac's built-in HDMI port, \
        which doesn't carry DDC. Connect it over USB-C / DisplayPort to control it, \
        and check that DDC/CI is enabled in the monitor's on-screen menu.
        """)
}

/// Shows the value of `code` (when `value` is nil) or sets it, across every
/// display the selector resolves to.
func runControl(_ code: VCPCode, on selector: DisplaySelector, value: UInt16?) throws {
    let displays = try targets(for: selector)
    let single = displays.count == 1

    print("")
    for display in displays {
        do {
            if let value {
                guard display.respondsToDDC() else { throw uncontrollableError(display) }
                try display.setVCP(code, value: value)
                print(setSummary(code, on: display, value: value))
            } else {
                print(readSummary(code, on: display, reading: try display.getVCP(code)))
            }
        } catch DDCError.featureUnsupported {
            if single {
                throw CLIError(description: "\(display.name) does not support \(code.name).")
            }
            print(skipLine(display, "does not support \(code.name)"))
        } catch {
            if single { throw uncontrollableError(display) }
            print(skipLine(display, "skipped — not controllable (no DDC/CI)"))
        }
    }
    print("")
}

private func readSummary(_ code: VCPCode, on display: Display, reading: VCPReading) -> String {
    let head = "  " + Tone.value(display.name) + "  " + Tone.subtle(code.name)
    if code == .inputSource {
        return head + "  " + Tone.accent(inputName(reading.current))
    }
    return head + "  " + Tone.accent("\(reading.current)")
        + Tone.muted(" / \(reading.maximum)")
}

private func setSummary(_ code: VCPCode, on display: Display, value: UInt16) -> String {
    let shown = (code == .inputSource) ? inputName(value) : "\(value)"
    return "  " + Tone.ok("✓") + "  " + Tone.value(display.name)
        + "  " + Tone.subtle(code.name) + " " + Tone.muted("→") + " " + Tone.accent(shown)
}

private func skipLine(_ display: Display, _ reason: String) -> String {
    "  " + Tone.warn("⚠") + "  " + Tone.value(display.name) + "  " + Tone.subtle(reason)
}

private func inputName(_ raw: UInt16) -> String {
    InputSource(rawValue: UInt8(truncatingIfNeeded: raw))?.name ?? "0x\(String(raw, radix: 16))"
}
