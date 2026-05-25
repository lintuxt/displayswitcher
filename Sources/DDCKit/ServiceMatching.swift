import Foundation
import IOKit
import CoreGraphics
import CIOAVService

/// Identifying fields of a display, read from CoreDisplay's info dictionary.
struct DisplayIdentity {
    var vendorID: Int = 0
    var productID: Int = 0
    var weekOfManufacture: Int = 0
    var yearOfManufacture: Int = 0
    var horizontalImageSize: Int = 0
    var verticalImageSize: Int = 0
    var ioDisplayLocation: String = ""
    var productName: String = ""
    var serialNumber: Int = 0
}

/// A candidate DDC service from the IORegistry: a framebuffer's identity
/// paired with the `IOAVService`-capable `DCPAVServiceProxy` that follows it.
struct ServiceCandidate {
    var edidUUID: String = ""
    var registryPath: String = ""
    var productName: String = ""
    var serialNumber: Int = 0
    var proxyService: io_service_t = 0
}

/// Matches `CGDisplay`s to their DDC/CI services by scoring every
/// display-against-service pairing and assigning greedily, best score first.
///
/// No single identifier is reliable across all hardware, so several weak
/// signals (EDID-UUID fragments, product name, serial) back up the one strong
/// signal (the IORegistry location). Ported from the MonitorControl project.
enum ServiceMatching {

    // MARK: Scoring (pure)

    /// Scores how well `identity` matches `candidate`. Higher is better; the
    /// location match dominates, the rest break ties.
    static func score(_ identity: DisplayIdentity, _ candidate: ServiceCandidate) -> Int {
        var score = edidUUIDScore(identity, edidUUID: candidate.edidUUID)
        if !identity.ioDisplayLocation.isEmpty,
           identity.ioDisplayLocation == candidate.registryPath {
            score += 10
        }
        if !candidate.productName.isEmpty,
           identity.productName.lowercased() == candidate.productName.lowercased() {
            score += 1
        }
        if candidate.serialNumber != 0, identity.serialNumber == candidate.serialNumber {
            score += 1
        }
        return score
    }

    /// Scores the four fixed-offset fragments of the EDID UUID — vendor,
    /// product, manufacture date, and image size — one point each.
    static func edidUUIDScore(_ identity: DisplayIdentity, edidUUID: String) -> Int {
        let fragments: [(key: String, offset: Int)] = [
            (hex(identity.vendorID, width: 4), 0),
            (hex(identity.productID & 0xFF, width: 2)
                + hex((identity.productID >> 8) & 0xFF, width: 2), 4),
            (hex(identity.weekOfManufacture, width: 2)
                + hex(identity.yearOfManufacture - 1990, width: 2), 19),
            (hex(identity.horizontalImageSize / 10, width: 2)
                + hex(identity.verticalImageSize / 10, width: 2), 30),
        ]
        let uuid = edidUUID.uppercased()
        var score = 0
        for fragment in fragments where fragment.key != "0000" {
            if fragmentOf(uuid, at: fragment.offset) == fragment.key {
                score += 1
            }
        }
        return score
    }

    /// Greedily pairs each display with a distinct service, highest score
    /// first. Pairs scoring zero are left unmatched.
    static func assign<Display: Hashable>(
        _ scored: [(display: Display, serviceIndex: Int, score: Int)]
    ) -> [(display: Display, serviceIndex: Int)] {
        var matches: [(Display, Int)] = []
        var takenDisplays: Set<Display> = []
        var takenServices: Set<Int> = []
        for pair in scored.sorted(by: { $0.score > $1.score }) where pair.score > 0 {
            guard !takenDisplays.contains(pair.display),
                  !takenServices.contains(pair.serviceIndex) else { continue }
            takenDisplays.insert(pair.display)
            takenServices.insert(pair.serviceIndex)
            matches.append((pair.display, pair.serviceIndex))
        }
        return matches
    }

    /// The 4-character fragment of `uuid` starting at `offset`, or "".
    private static func fragmentOf(_ uuid: String, at offset: Int) -> String {
        guard uuid.count >= offset + 4 else { return "" }
        let start = uuid.index(uuid.startIndex, offsetBy: offset)
        let end = uuid.index(start, offsetBy: 4)
        return String(uuid[start..<end])
    }

    /// Zero-padded uppercase hex of `value`, clamped to fit `width` digits.
    private static func hex(_ value: Int, width: Int) -> String {
        let maxValue = (1 << (width * 4)) - 1
        let digits = String(max(0, min(value, maxValue)), radix: 16, uppercase: true)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }

    // MARK: IORegistry / CoreDisplay (hardware)

    /// Reads a display's identity from CoreDisplay's private info dictionary.
    static func displayIdentity(for displayID: CGDirectDisplayID) -> DisplayIdentity? {
        guard let info = ds_display_info_dictionary(displayID) as NSDictionary? else {
            return nil
        }
        var identity = DisplayIdentity()
        identity.vendorID = intValue(info, "DisplayVendorID")
        identity.productID = intValue(info, "DisplayProductID")
        identity.weekOfManufacture = intValue(info, "DisplayWeekOfManufacture")
        identity.yearOfManufacture = intValue(info, "DisplayYearOfManufacture")
        identity.horizontalImageSize = intValue(info, "DisplayHorizontalImageSize")
        identity.verticalImageSize = intValue(info, "DisplayVerticalImageSize")
        identity.serialNumber = intValue(info, "DisplaySerialNumber")
        identity.ioDisplayLocation = (info["IODisplayLocation"] as? String) ?? ""
        if let names = info["DisplayProductName"] as? [String: String] {
            identity.productName = names["en_US"] ?? names.first?.value ?? ""
        }
        return identity
    }

    /// Walks the IORegistry collecting every framebuffer + `DCPAVServiceProxy`
    /// pair. The caller owns each candidate's `proxyService` and must release
    /// it with `IOObjectRelease`.
    static func gatherCandidates() -> [ServiceCandidate] {
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        var iterator = io_iterator_t()
        guard IORegistryEntryCreateIterator(
            root, kIOServicePlane,
            IOOptionBits(kIORegistryIterateRecursively), &iterator
        ) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        let framebufferNames: Set<String> = ["AppleCLCD2", "IOMobileFramebufferShim"]
        var candidates: [ServiceCandidate] = []
        var framebuffer = ServiceCandidate()

        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            let name = entryName(entry)
            var keepEntry = false
            if framebufferNames.contains(name) {
                framebuffer = framebufferIdentity(entry)
            } else if name == "DCPAVServiceProxy", locationIsExternal(entry) {
                var candidate = framebuffer
                candidate.proxyService = entry
                candidates.append(candidate)
                keepEntry = true // released by the caller
            }
            if !keepEntry { IOObjectRelease(entry) }
            entry = IOIteratorNext(iterator)
        }
        return candidates
    }

    /// Reads a framebuffer node's EDID UUID, registry path, and product info.
    private static func framebufferIdentity(_ entry: io_service_t) -> ServiceCandidate {
        var candidate = ServiceCandidate()
        candidate.edidUUID = (property(entry, "EDID UUID") as? String) ?? ""
        candidate.registryPath = entryPath(entry) ?? ""
        if let attributes = property(entry, "DisplayAttributes") as? NSDictionary,
           let product = attributes["ProductAttributes"] as? NSDictionary {
            candidate.productName = (product["ProductName"] as? String) ?? ""
            candidate.serialNumber = (product["SerialNumber"] as? Int) ?? 0
        }
        return candidate
    }

    private static func property(_ entry: io_service_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(
            entry, key as CFString, kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively)
        )?.takeRetainedValue()
    }

    private static func intValue(_ dictionary: NSDictionary, _ key: String) -> Int {
        (dictionary[key] as? NSNumber)?.intValue ?? 0
    }

    private static func entryName(_ entry: io_service_t) -> String {
        var buffer = [CChar](repeating: 0, count: 128)
        guard IORegistryEntryGetName(entry, &buffer) == KERN_SUCCESS else { return "" }
        return String(cString: buffer)
    }

    private static func entryPath(_ entry: io_service_t) -> String? {
        IORegistryEntryCopyPath(entry, kIOServicePlane)?.takeRetainedValue() as String?
    }

    private static func locationIsExternal(_ entry: io_service_t) -> Bool {
        (property(entry, "Location") as? String) == "External"
    }
}
