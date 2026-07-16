import XCTest
@testable import VowriteKit

/// F-081: Per-app auto Mode — pure decision logic. Covers every branch of
/// `PerAppModeDecision.resolve` (feature off, translate session, no mapping,
/// missing mapped Mode, pin pending/bound/cross-app-clear) plus the
/// mapping lookup and the encode/decode round trip used by
/// `PerAppModeManager` (VowriteMac, no test target of its own).
final class PerAppModeDecisionTests: XCTestCase {

    private let modeA = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private let modeB = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
    private let deletedMode = UUID(uuidString: "00000000-0000-0000-0000-00000000DEAD")!

    // MARK: - lookupMapping

    func testLookupNoMappingForUnknownBundleID() {
        let result = PerAppModeDecision.lookupMapping(
            bundleID: "com.example.unmapped",
            mapping: ["com.slack.desktop": modeA],
            availableModeIds: [modeA]
        )
        XCTAssertEqual(result, .noMapping)
    }

    func testLookupMappedWhenTargetModeExists() {
        let result = PerAppModeDecision.lookupMapping(
            bundleID: "com.slack.desktop",
            mapping: ["com.slack.desktop": modeA],
            availableModeIds: [modeA, modeB]
        )
        XCTAssertEqual(result, .mapped(modeId: modeA))
    }

    func testLookupMissingModeWhenTargetModeWasDeleted() {
        let result = PerAppModeDecision.lookupMapping(
            bundleID: "com.slack.desktop",
            mapping: ["com.slack.desktop": deletedMode],
            availableModeIds: [modeA, modeB]
        )
        XCTAssertEqual(result, .missingMode)
    }

    // MARK: - resolve: feature off / translate session / no bundle id

    func testFeatureDisabledAlwaysNoOverride() {
        let (action, pin) = PerAppModeDecision.resolve(
            enabled: false,
            isTranslateSession: false,
            bundleID: "com.slack.desktop",
            lookup: .mapped(modeId: modeA),
            pin: .none
        )
        XCTAssertEqual(action, .noOverride)
        XCTAssertEqual(pin, .none)
    }

    func testTranslateSessionNeverAppliesMapping() {
        let (action, pin) = PerAppModeDecision.resolve(
            enabled: true,
            isTranslateSession: true,
            bundleID: "com.slack.desktop",
            lookup: .mapped(modeId: modeA),
            pin: .none
        )
        XCTAssertEqual(action, .noOverride)
        XCTAssertEqual(pin, .none, "translate sessions must not perturb pin state")
    }

    func testNilBundleIDNoOverridePinUntouched() {
        let (action, pin) = PerAppModeDecision.resolve(
            enabled: true,
            isTranslateSession: false,
            bundleID: nil,
            lookup: .noMapping,
            pin: .bound(bundleID: "com.slack.desktop")
        )
        XCTAssertEqual(action, .noOverride)
        XCTAssertEqual(pin, .bound(bundleID: "com.slack.desktop"))
    }

    // MARK: - resolve: no mapping / missing mode

    func testNoMappingForFrontmostAppNoOverridePinCarriesForward() {
        let (action, pin) = PerAppModeDecision.resolve(
            enabled: true,
            isTranslateSession: false,
            bundleID: "com.example.unmapped",
            lookup: .noMapping,
            pin: .pending
        )
        XCTAssertEqual(action, .noOverride)
        XCTAssertEqual(pin, .pending, "an unmapped app in between must not clear a pending pin")
    }

    func testMissingModeTreatedAsNoOverride() {
        let (action, pin) = PerAppModeDecision.resolve(
            enabled: true,
            isTranslateSession: false,
            bundleID: "com.slack.desktop",
            lookup: .missingMode,
            pin: .none
        )
        XCTAssertEqual(action, .noOverride)
        XCTAssertEqual(pin, .none)
    }

    // MARK: - resolve: pin == .none (normal mapping hit)

    func testMappingHitWithNoPinAppliesOverride() {
        let (action, pin) = PerAppModeDecision.resolve(
            enabled: true,
            isTranslateSession: false,
            bundleID: "com.slack.desktop",
            lookup: .mapped(modeId: modeA),
            pin: .none
        )
        XCTAssertEqual(action, .applyOverride(modeId: modeA))
        XCTAssertEqual(pin, .none)
    }

    // MARK: - resolve: pin == .pending (first recording after manual switch)

    func testPendingPinBindsToFrontmostAppAndSkipsMappingOnce() {
        let (action, pin) = PerAppModeDecision.resolve(
            enabled: true,
            isTranslateSession: false,
            bundleID: "com.slack.desktop",
            lookup: .mapped(modeId: modeA),
            pin: .pending
        )
        XCTAssertEqual(action, .noOverride, "the recording right after a manual switch must not be re-overridden")
        XCTAssertEqual(pin, .bound(bundleID: "com.slack.desktop"))
    }

    func testPendingPinWithNoMappingLeavesPinPending() {
        let (action, pin) = PerAppModeDecision.resolve(
            enabled: true,
            isTranslateSession: false,
            bundleID: "com.example.unmapped",
            lookup: .noMapping,
            pin: .pending
        )
        XCTAssertEqual(action, .noOverride)
        XCTAssertEqual(pin, .pending, "pending only binds on a mapping hit, not any recording")
    }

    // MARK: - resolve: pin == .bound (steady state)

    func testBoundPinSameAppKeepsSkippingMapping() {
        let (action, pin) = PerAppModeDecision.resolve(
            enabled: true,
            isTranslateSession: false,
            bundleID: "com.slack.desktop",
            lookup: .mapped(modeId: modeA),
            pin: .bound(bundleID: "com.slack.desktop")
        )
        XCTAssertEqual(action, .noOverride)
        XCTAssertEqual(pin, .bound(bundleID: "com.slack.desktop"))
    }

    func testBoundPinDifferentMappedAppClearsPinAndApplies() {
        let (action, pin) = PerAppModeDecision.resolve(
            enabled: true,
            isTranslateSession: false,
            bundleID: "com.microsoft.VSCode",
            lookup: .mapped(modeId: modeB),
            pin: .bound(bundleID: "com.slack.desktop")
        )
        XCTAssertEqual(action, .applyOverride(modeId: modeB))
        XCTAssertEqual(pin, .none, "moving to a different MAPPED app clears the pin")
    }

    func testBoundPinDifferentUnmappedAppLeavesPinBound() {
        let (action, pin) = PerAppModeDecision.resolve(
            enabled: true,
            isTranslateSession: false,
            bundleID: "com.apple.finder",
            lookup: .noMapping,
            pin: .bound(bundleID: "com.slack.desktop")
        )
        XCTAssertEqual(action, .noOverride)
        XCTAssertEqual(pin, .bound(bundleID: "com.slack.desktop"), "an unmapped app must not clear a bound pin")
    }

    // MARK: - PerAppModeMapping encode/decode

    func testMappingRoundTripsThroughEncodeDecode() {
        let mapping: [String: UUID] = [
            "com.slack.desktop": modeA,
            "com.microsoft.VSCode": modeB
        ]
        let data = PerAppModeMapping.encode(mapping)
        XCTAssertNotNil(data)
        let decoded = PerAppModeMapping.decode(data)
        XCTAssertEqual(decoded, mapping)
    }

    func testEmptyMappingRoundTrips() {
        let data = PerAppModeMapping.encode([:])
        XCTAssertEqual(PerAppModeMapping.decode(data), [:])
    }

    func testDecodeNilDataReturnsEmptyMapping() {
        XCTAssertEqual(PerAppModeMapping.decode(nil), [:])
    }

    func testDecodeCorruptDataReturnsEmptyMappingRatherThanCrashing() {
        let garbage = Data("not json".utf8)
        XCTAssertEqual(PerAppModeMapping.decode(garbage), [:])
    }
}
