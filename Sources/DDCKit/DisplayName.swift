import Foundation

/// Removes the " (N)" suffix that macOS appends to disambiguate displays
/// with identical names, e.g. "DELL U2715H (3)" -> "DELL U2715H".
///
/// A parenthetical that is not purely a number (e.g. "(Pro)") is left intact,
/// since that is part of the real product name.
func strippedDisplayName(_ raw: String) -> String {
    guard raw.hasSuffix(")"),
          let open = raw.range(of: " (", options: .backwards)
    else {
        return raw
    }
    let digitsStart = raw.index(open.lowerBound, offsetBy: 2)
    let inside = raw[digitsStart..<raw.index(before: raw.endIndex)]
    guard !inside.isEmpty, inside.allSatisfy(\.isNumber) else { return raw }
    return String(raw[..<open.lowerBound])
}
