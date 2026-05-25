import XCTest
@testable import DDCKit

final class ServiceMatchingTests: XCTestCase {

    // MARK: Greedy assignment

    func testAssignsHighestScoringPairsFirst() {
        let scored: [(display: Int, serviceIndex: Int, score: Int)] = [
            (display: 1, serviceIndex: 0, score: 5),
            (display: 1, serviceIndex: 1, score: 10),
            (display: 2, serviceIndex: 0, score: 8),
            (display: 2, serviceIndex: 1, score: 3),
        ]
        let result = Dictionary(uniqueKeysWithValues:
            ServiceMatching.assign(scored).map { ($0.display, $0.serviceIndex) })
        XCTAssertEqual(result, [1: 1, 2: 0])
    }

    func testLeavesZeroScoredPairsUnmatched() {
        let scored: [(display: Int, serviceIndex: Int, score: Int)] = [
            (display: 1, serviceIndex: 0, score: 0),
        ]
        XCTAssertTrue(ServiceMatching.assign(scored).isEmpty)
    }

    func testAssignsEachServiceAtMostOnce() {
        // Both displays score best on service 0 — only one may take it.
        let scored: [(display: Int, serviceIndex: Int, score: Int)] = [
            (display: 1, serviceIndex: 0, score: 10),
            (display: 2, serviceIndex: 0, score: 9),
            (display: 2, serviceIndex: 1, score: 4),
        ]
        let result = Dictionary(uniqueKeysWithValues:
            ServiceMatching.assign(scored).map { ($0.display, $0.serviceIndex) })
        XCTAssertEqual(result, [1: 0, 2: 1])
    }

    // MARK: EDID-UUID fragment scoring

    /// The EDID UUID of a real Dell U2715H.
    private let dellUUID = "10AC67D0-0000-0000-171B-0103803C2278"

    func testScoresAllFourEDIDFragments() {
        let identity = DisplayIdentity(
            vendorID: 0x10AC,                // -> "10AC" at offset 0
            productID: 0xD067,               // low+high byte -> "67D0" at offset 4
            weekOfManufacture: 0x17,         // -> "17"
            yearOfManufacture: 1990 + 0x1B,  // year - 1990 -> "1B"  (offset 19: "171B")
            horizontalImageSize: 600,        // / 10 -> "3C"
            verticalImageSize: 340)          // / 10 -> "22"  (offset 30: "3C22")
        XCTAssertEqual(ServiceMatching.edidUUIDScore(identity, edidUUID: dellUUID), 4)
    }

    func testUnrelatedDisplayScoresNoEDIDFragments() {
        let identity = DisplayIdentity(vendorID: 0x0610, productID: 0x1234)
        XCTAssertEqual(ServiceMatching.edidUUIDScore(identity, edidUUID: dellUUID), 0)
    }

    // MARK: Combined score

    func testLocationMatchScoresTen() {
        let identity = DisplayIdentity(ioDisplayLocation: "/AppleARMPE@0/path")
        let candidate = ServiceCandidate(registryPath: "/AppleARMPE@0/path")
        XCTAssertEqual(ServiceMatching.score(identity, candidate), 10)
    }

    func testProductNameAndSerialEachScoreOne() {
        let identity = DisplayIdentity(productName: "DELL U2715H", serialNumber: 42)
        let candidate = ServiceCandidate(productName: "dell u2715h", serialNumber: 42)
        XCTAssertEqual(ServiceMatching.score(identity, candidate), 2)
    }
}
