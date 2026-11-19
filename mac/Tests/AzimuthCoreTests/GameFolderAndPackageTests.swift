import XCTest
@testable import AzimuthCore

final class GameFolderAndPackageTests: XCTestCase {
    private var temp: URL!

    override func setUpWithError() throws {
        temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temp)
    }

    private func makeDir(_ relative: String) throws {
        try FileManager.default.createDirectory(
            at: temp.appendingPathComponent(relative), withIntermediateDirectories: true)
    }

    private func makeFile(_ relative: String, _ text: String = "x") throws {
        let url = temp.appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: GameFolder

    func testFolderWithMountIsValid() throws {
        try makeDir("game/Mount")
        XCTAssertEqual(GameFolder.check(temp.appendingPathComponent("game")), .valid)
    }

    func testParentOfGameSuggestsSubfolder() throws {
        try makeDir("games/Forza/Mount")
        let result = GameFolder.check(temp.appendingPathComponent("games"))
        guard case .useSubfolder(let inner) = result else { return XCTFail("got \(result)") }
        XCTAssertEqual(inner.lastPathComponent, "Forza")
    }

    func testFolderWithoutMount() throws {
        try makeDir("empty/Other")
        XCTAssertEqual(GameFolder.check(temp.appendingPathComponent("empty")), .missingMount)
    }

    func testMissingPathIsNotAFolder() {
        XCTAssertEqual(GameFolder.check(temp.appendingPathComponent("nope")), .notAFolder)
    }

    // MARK: AzimuthPackage

    private func makeFakePackage(at relative: String, omitting: String? = nil) throws {
        for file in AzimuthPackage.requiredFiles where file != omitting {
            try makeFile("\(relative)/\(file)", "new")
        }
    }

    func testFindsRootInsideWrapperFolder() throws {
        try makeFakePackage(at: "unpacked/azimuth-windows")
        let root = AzimuthPackage.findRoot(in: temp.appendingPathComponent("unpacked"))
        XCTAssertEqual(root?.lastPathComponent, "azimuth-windows")
    }

    func testInstallCopiesAndKeepsUserFiles() throws {
        try makeFakePackage(at: "unpacked/azimuth-windows")
        try makeFile("dest/azimuth.ini", "[launcher]\ngame_folder=G:\\\n")
        try makeFile("dest/azimuth.exe", "old")

        try AzimuthPackage.install(
            unpackedAt: temp.appendingPathComponent("unpacked"),
            into: temp.appendingPathComponent("dest"))

        let dest = temp.appendingPathComponent("dest")
        XCTAssertTrue(AzimuthPackage.isInstalled(at: dest))
        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("azimuth.exe"), encoding: .utf8), "new")
        XCTAssertEqual(
            try String(contentsOf: dest.appendingPathComponent("azimuth.ini"), encoding: .utf8),
            "[launcher]\ngame_folder=G:\\\n")
    }

    func testIncompletePackageIsRejectedAndNothingIsCopied() throws {
        try makeFakePackage(at: "unpacked/azimuth-windows", omitting: "data/bin/msvcr110.dll")
        XCTAssertThrowsError(try AzimuthPackage.install(
            unpackedAt: temp.appendingPathComponent("unpacked"),
            into: temp.appendingPathComponent("dest"))
        ) { error in
            guard case AzimuthPackage.PackageError.incomplete(let missing) = error else {
                return XCTFail("wrong error \(error)")
            }
            XCTAssertEqual(missing, ["data/bin/msvcr110.dll"])
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.appendingPathComponent("dest").path))
    }

    func testInstallFromRealZip() throws {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/zip"),
              FileManager.default.isExecutableFile(atPath: "/usr/bin/unzip")
        else { throw XCTSkip("zip tools not available") }

        try makeFakePackage(at: "src/azimuth-windows")
        try makeFile("src/__MACOSX/azimuth-windows/._azimuth.exe", "junk")
        let zip = temp.appendingPathComponent("azimuth-windows.zip")
        let made = try Shell.run(
            "/usr/bin/zip", ["-qr", zip.path, "azimuth-windows", "__MACOSX"],
            currentDirectory: temp.appendingPathComponent("src"))
        XCTAssertTrue(made.succeeded, made.output)

        let dest = temp.appendingPathComponent("dest")
        try AzimuthPackage.install(zip: zip, into: dest)
        XCTAssertTrue(AzimuthPackage.isInstalled(at: dest))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dest.appendingPathComponent("__MACOSX").path))
    }
}
