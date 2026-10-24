import XCTest
@testable import AzimuthCore

final class DiagnosisTests: XCTestCase {
    func testRecognisesMissingHeapSupport() {
        let log = "graphics: the D3D12 driver cannot open heaps over existing memory\n"
        let findings = Diagnosis.analyze(log)
        XCTAssertEqual(findings.count, 1)
        XCTAssertTrue(findings[0].title.contains("existing memory"))
    }

    func testRecognisesLowBindingTier() {
        let findings = Diagnosis.analyze("the D3D12 driver's resource binding tier is below 3")
        XCTAssertTrue(findings.contains { $0.title.contains("binding tier 3") })
    }

    func testRecognisesWineMissingDirect3D() {
        let log = #"err:module:import_dll Library d3d12.dll (which is needed by L"C:\\Azimuth\\azimuth.exe") not found"#
        XCTAssertTrue(Diagnosis.analyze(log).contains { $0.title.contains("load Direct3D 12") })
    }

    func testRuntimeOverrideMessage() {
        let log = "Private VC11 runtime was overridden. For Proton set WINEDLLOVERRIDES=..."
        XCTAssertTrue(Diagnosis.analyze(log).contains { $0.title.contains("Visual C++ runtime") })
    }

    func testMatchingIgnoresCase() {
        XCTAssertFalse(Diagnosis.analyze("YOUR PROCESSOR IS NOT SUPPORTED").isEmpty)
    }

    func testCleanLogHasNoFindings() {
        XCTAssertTrue(Diagnosis.analyze("Azimuth started\nPreparing graphics pipelines\n").isEmpty)
    }

    func testTailReadsOnlyTheEnd() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: file) }
        try String(repeating: "a", count: 1000).appending("END").write(to: file, atomically: true, encoding: .utf8)
        let tail = Diagnosis.tail(of: file, maxBytes: 10)
        XCTAssertEqual(tail.count, 10)
        XCTAssertTrue(tail.hasSuffix("END"))
    }

    func testMissingLogGivesEmptyTail() {
        XCTAssertEqual(Diagnosis.tail(of: URL(fileURLWithPath: "/nonexistent/azimuth.log"), maxBytes: 100), "")
    }
}
