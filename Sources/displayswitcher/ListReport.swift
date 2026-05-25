import CLIKit
import DDCKit
import Foundation

/// Prints the `--list` report: a banner, a table of every external display
/// with its current settings, and a 3×3 map of their physical arrangement.
func runList() throws {
    printBanner()

    let displays = try DisplayManager.displays().sorted { $0.id < $1.id }
    guard !displays.isEmpty else {
        print("  " + Tone.warn("No external displays found."))
        printSponsorFooter()
        return
    }

    var rows: [[String]] = []
    var hasUncontrollable = false
    for display in displays {
        // The brightness read doubles as the DDC/CI reachability probe.
        let brightness = try? display.getVCP(.brightness)
        var contrast: VCPReading?
        var input: VCPReading?
        if brightness != nil {
            contrast = try? display.getVCP(.contrast)
            input = try? display.getVCP(.inputSource)
        } else {
            hasUncontrollable = true
        }
        rows.append([
            Tone.accent("\(display.id)"),
            Tone.value(display.name),
            cell(display.geometry.map { "\($0.width) × \($0.height)" } ?? "—"),
            cell(percentage(brightness)),
            cell(percentage(contrast)),
            cell(inputLabel(input)),
        ])
    }

    let headers = ["#", "Monitor", "Resolution", "Brightness", "Contrast", "Input"]
        .map { Tone.heading($0) }
    let count = displays.count

    print("  " + Tone.muted("\(count) display\(count == 1 ? "" : "s") — pass # to --on-display"))
    print("")
    print(indented(BoxTable.render(headers: headers, rows: rows)))

    if let layout = layoutGrid(displays) {
        print("")
        print("  " + Tone.muted("Physical layout"))
        print(indented(layout))
    }
    if hasUncontrollable {
        print("")
        print("  " + Tone.subtle("A dash (—) marks a display that doesn't support DDC/CI."))
    }
    printSponsorFooter()
}

/// The product banner: name, version, tagline.
func printBanner() {
    Banner.printBanner(name: "displayswitcher", version: BuildInfo.version,
                       tagline: "external monitor control")
}

/// The "looking for sponsors" footer line.
func printSponsorFooter() {
    Banner.printSponsorFooter(url: "https://github.com/sponsors/lintuxt")
}

/// Styles a settings cell — dim for an unavailable "—", bright otherwise.
private func cell(_ text: String) -> String {
    text == "—" ? Tone.subtle(text) : Tone.value(text)
}

/// Indents every line of a multi-line block by two spaces.
private func indented(_ block: String) -> String {
    block.split(separator: "\n", omittingEmptySubsequences: false)
        .map { "  " + $0 }
        .joined(separator: "\n")
}

/// Formats a reading as a whole-percent string, or "—" when unavailable.
private func percentage(_ reading: VCPReading?) -> String {
    guard let reading, reading.maximum > 0 else { return "—" }
    let percent = Double(reading.current) / Double(reading.maximum) * 100
    return "\(Int(percent.rounded()))%"
}

/// Formats an input-source reading as a friendly name, or "—".
private func inputLabel(_ reading: VCPReading?) -> String {
    guard let reading else { return "—" }
    let code = UInt8(truncatingIfNeeded: reading.current)
    return InputSource(rawValue: code)?.name ?? "0x" + String(code, radix: 16)
}

/// A 3×3 grid placing each display's number by its position on the desktop,
/// so identical monitors can be told apart. Returns nil when no display
/// reports geometry.
private func layoutGrid(_ displays: [Display]) -> String? {
    let placed = displays.compactMap { display -> (x: Int, y: Int, id: Int)? in
        guard let g = display.geometry else { return nil }
        return (g.originX + g.width / 2, g.originY + g.height / 2, display.id)
    }
    guard !placed.isEmpty else { return nil }

    let xs = placed.map(\.x), ys = placed.map(\.y)
    let (minX, maxX) = (xs.min()!, xs.max()!)
    let (minY, maxY) = (ys.min()!, ys.max()!)

    var cells = [[[String]]](repeating: [[String]](repeating: [], count: 3), count: 3)
    for display in placed {
        let column = third(display.x, between: minX, and: maxX)
        let row = third(display.y, between: minY, and: maxY)
        cells[row][column].append("\(display.id)")
    }
    let rendered = cells.map { row in
        row.map { ids in
            ids.isEmpty ? Tone.subtle("·") : Tone.accent(ids.joined(separator: ","))
        }
    }
    return BoxTable.grid(rendered)
}

/// Buckets `value` into thirds (0, 1, 2) of the `[lo, hi]` range.
private func third(_ value: Int, between lo: Int, and hi: Int) -> Int {
    guard hi > lo else { return 1 }
    let fraction = Double(value - lo) / Double(hi - lo)
    return min(2, max(0, Int((fraction * 2).rounded())))
}
