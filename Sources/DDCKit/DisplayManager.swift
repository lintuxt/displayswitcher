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
        if let demo = ProcessInfo.processInfo.environment["LINTUXT_DEBUG"], !demo.isEmpty {
            return demoDisplays()
        }
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

    /// A deterministic three-display scene used only to regenerate the
    /// lintuxt.ai terminal mock. Gated behind the hidden LINTUXT_DEBUG env
    /// var; deliberately undocumented and never a public flag.
    private static func demoDisplays() -> [Display] {
        let readings: [VCPCode: VCPReading] = [
            .brightness: VCPReading(current: 25, maximum: 100),
            .contrast: VCPReading(current: 50, maximum: 100),
            .inputSource: VCPReading(current: UInt16(InputSource.hdmi1.rawValue),
                                     maximum: UInt16(InputSource.hdmi1.rawValue)),
        ]
        func make(id: Int, originX: Int) -> Display {
            Display(id: id, name: "DELL U2715H",
                    geometry: DisplayGeometry(width: 2560, height: 1440,
                                              originX: originX, originY: 0),
                    transport: FixtureTransport(readings: readings),
                    interCommandDelay: 0)
        }
        // id 1 centre, 2 left, 3 right -> layout map renders `2 1 3`.
        return [make(id: 1, originX: 2560),
                make(id: 2, originX: 0),
                make(id: 3, originX: 5120)]
    }
}
