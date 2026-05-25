import Foundation
import IOKit
import CoreGraphics
import AppKit
import CIOAVService

/// Discovers controllable external displays.
///
/// Each `CGDisplay` is paired with its own DDC/CI service by `ServiceMatching`,
/// which scores every display-against-service combination and assigns them
/// greedily. This is robust to multiple identical monitors — each is driven
/// through the correct service rather than a guess by enumeration order.
public enum DisplayManager {

    /// Returns every controllable external display, ordered by `id` (1-based).
    public static func displays() throws -> [Display] {
        guard ds_ioav_available() != 0 else {
            throw DDCError.ioavServiceUnavailable
        }

        let candidates = ServiceMatching.gatherCandidates()
        defer { candidates.forEach { IOObjectRelease($0.proxyService) } }

        // Score every (display, service) pair, then assign one service each.
        var scored: [(display: CGDirectDisplayID, serviceIndex: Int, score: Int)] = []
        for displayID in externalDisplayIDs() {
            guard let identity = ServiceMatching.displayIdentity(for: displayID) else { continue }
            for (index, candidate) in candidates.enumerated() {
                scored.append((displayID, index, ServiceMatching.score(identity, candidate)))
            }
        }
        let matches = ServiceMatching.assign(scored)

        // Build displays, numbered 1-based by ascending display ID.
        var displays: [Display] = []
        for match in matches.sorted(by: { $0.display < $1.display }) {
            let service = candidates[match.serviceIndex].proxyService
            guard let transport = try? AppleSiliconTransport(ioService: service) else { continue }
            let rawName = localizedName(for: match.display) ?? "Display \(displays.count + 1)"
            displays.append(Display(id: displays.count + 1,
                                    name: strippedDisplayName(rawName),
                                    geometry: geometry(for: match.display),
                                    transport: transport))
        }
        return displays
    }

    /// Active external display IDs, sorted for run-to-run stability.
    private static func externalDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return ids
            .filter { CGDisplayIsBuiltin($0) == 0 && CGDisplayIsActive($0) != 0 }
            .sorted()
    }

    /// Pixel resolution and desktop position for a display.
    private static func geometry(for displayID: CGDirectDisplayID) -> DisplayGeometry {
        let bounds = CGDisplayBounds(displayID)
        return DisplayGeometry(width: CGDisplayPixelsWide(displayID),
                               height: CGDisplayPixelsHigh(displayID),
                               originX: Int(bounds.origin.x),
                               originY: Int(bounds.origin.y))
    }

    /// The OS-provided display name (e.g. "DELL U2715H"), if available.
    private static func localizedName(for displayID: CGDirectDisplayID) -> String? {
        let screenNumberKey = NSDeviceDescriptionKey("NSScreenNumber")
        return NSScreen.screens.first {
            ($0.deviceDescription[screenNumberKey] as? CGDirectDisplayID) == displayID
        }?.localizedName
    }
}
