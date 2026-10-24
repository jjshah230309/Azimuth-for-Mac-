import XCTest
@testable import AzimuthCore

final class EngineAndEnvironmentTests: XCTestCase {
    private var temp: URL!

    override func setUpWithError() throws {
        temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temp)
    }

    private func makeFakeEngine(named name: String) throws -> URL {
        let bin = temp.appendingPathComponent("\(name)/bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let wine = bin.appendingPathComponent("wine64")
        try "#!/bin/sh\n".write(to: wine, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wine.path)
        return wine
    }

    // MARK: Engine

    func testLocateReturnsNilWhenNothingInstalled() {
        XCTAssertNil(Engine.locate(candidates: [temp.appendingPathComponent("none/bin/wine64").path]))
    }

    func testLocatePrefersTheUsersChoice() throws {
        let chosen = try makeFakeEngine(named: "chosen")
        let other = try makeFakeEngine(named: "other")
        let engine = Engine.locate(preferred: chosen.path, candidates: [other.path])
        XCTAssertEqual(engine?.wine64.path, chosen.path)
    }

    func testLocateFallsBackToCandidates() throws {
        let other = try makeFakeEngine(named: "other")
        let engine = Engine.locate(preferred: "/nonexistent/wine64", candidates: [other.path])
        XCTAssertEqual(engine?.wine64.path, other.path)
    }

    func testLibraryLayoutIsSiblingOfBin() throws {
        let engine = Engine(wine64: try makeFakeEngine(named: "kit"))
        XCTAssertEqual(engine.libDirectory.lastPathComponent, "lib")
        XCTAssertEqual(engine.libDirectory.deletingLastPathComponent().lastPathComponent, "kit")
        XCTAssertFalse(engine.hasD3DMetal)
    }

    func testDetectsD3DMetalOnceInstalled() throws {
        let engine = Engine(wine64: try makeFakeEngine(named: "kit"))
        try FileManager.default.createDirectory(
            at: engine.d3dMetalFramework, withIntermediateDirectories: true)
        XCTAssertFalse(engine.hasD3DMetal, "the shared library is still missing")
        try "x".write(to: engine.d3dSharedLibrary, atomically: true, encoding: .utf8)
        XCTAssertTrue(engine.hasD3DMetal)
    }

    func testFindsRedistLibInsideMountedVolume() throws {
        let lib = temp.appendingPathComponent("Volume/Game Porting Toolkit/redist/lib")
        try FileManager.default.createDirectory(at: lib, withIntermediateDirectories: true)
        let found = Engine.findRedistLib(in: temp.appendingPathComponent("Volume"))
        XCTAssertEqual(found?.lastPathComponent, "lib")
        XCTAssertNil(Engine.findRedistLib(in: temp.appendingPathComponent("elsewhere")))
    }

    func testInstallD3DMetalFromFolderWithoutRedistThrows() throws {
        let engine = Engine(wine64: try makeFakeEngine(named: "kit"))
        let empty = temp.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        XCTAssertThrowsError(try engine.installD3DMetal(from: empty))
    }

    func testReadsMountPointFromHdiutilPlist() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>system-entities</key><array>
        <dict><key>dev-entry</key><string>/dev/disk4</string></dict>
        <dict><key>mount-point</key><string>/Volumes/Game Porting Toolkit</string></dict>
        </array></dict></plist>
        """
        XCTAssertEqual(Engine.mountPoint(fromHdiutilPlist: plist)?.path, "/Volumes/Game Porting Toolkit")
        XCTAssertNil(Engine.mountPoint(fromHdiutilPlist: "not a plist"))
    }

    // MARK: Environment

    func testEnvironmentCarriesWineSettings() throws {
        let engine = Engine(wine64: try makeFakeEngine(named: "kit"))
        let paths = AppPaths(root: temp.appendingPathComponent("app"))
        let env = WineEnvironment.make(engine: engine, paths: paths, base: ["PATH": "/usr/bin"])

        XCTAssertEqual(env["WINEPREFIX"], paths.prefix.path)
        XCTAssertEqual(env["WINEDLLOVERRIDES"], "msvcr110,msvcp110,d3dcompiler_47=n")
        XCTAssertEqual(env["ROSETTA_ADVERTISE_AVX"], "1")
        XCTAssertNil(env["MTL_HUD_ENABLED"])
        XCTAssertTrue(try XCTUnwrap(env["PATH"]).hasPrefix(engine.binDirectory.path + ":"))
        XCTAssertTrue(try XCTUnwrap(env["PATH"]).hasSuffix(":/usr/bin"))
    }

    func testOptionsChangeEnvironment() throws {
        let engine = Engine(wine64: try makeFakeEngine(named: "kit"))
        let paths = AppPaths(root: temp)
        var options = LaunchOptions()
        options.advertiseAVX = false
        options.metalHUD = true
        options.verboseLogs = true
        let env = WineEnvironment.make(engine: engine, paths: paths, options: options, base: [:])

        XCTAssertNil(env["ROSETTA_ADVERTISE_AVX"])
        XCTAssertEqual(env["MTL_HUD_ENABLED"], "1")
        XCTAssertTrue(try XCTUnwrap(env["WINEDEBUG"]).contains("+seh"))
    }

    func testArgumentsHonourSkipLauncher() {
        var options = LaunchOptions()
        XCTAssertEqual(WineEnvironment.azimuthArguments(options: options), ["C:\\Azimuth\\azimuth.exe"])
        options.skipAzimuthLauncher = true
        XCTAssertEqual(
            WineEnvironment.azimuthArguments(options: options),
            ["C:\\Azimuth\\azimuth.exe", "--skip-launcher"])
    }

    // MARK: Paths, settings and DLL checks

    func testPathsStayInsideRoot() {
        let paths = AppPaths(root: URL(fileURLWithPath: "/tmp/azimuth-test"))
        XCTAssertEqual(paths.azimuthExecutable.path, "/tmp/azimuth-test/prefix/drive_c/Azimuth/azimuth.exe")
        XCTAssertEqual(paths.system32.path, "/tmp/azimuth-test/prefix/drive_c/windows/system32")
    }

    func testSettingsRoundTrip() throws {
        var settings = LauncherSettings()
        settings.gameFolder = "/Users/me/Games/Forza"
        settings.options.metalHUD = true
        let file = temp.appendingPathComponent("config/launcher.json")
        try settings.save(to: file)
        XCTAssertEqual(LauncherSettings.load(from: file), settings)
        XCTAssertEqual(LauncherSettings.load(from: temp.appendingPathComponent("missing.json")), LauncherSettings())
    }

    func testPEFileRecognisesX64DLL() throws {
        var bytes = [UInt8](repeating: 0, count: 0x100)
        bytes[0] = 0x4D; bytes[1] = 0x5A            // MZ
        bytes[0x3C] = 0x80                          // PE header at 0x80
        bytes[0x80] = 0x50; bytes[0x81] = 0x45      // PE\0\0
        bytes[0x84] = 0x64; bytes[0x85] = 0x86      // machine 0x8664
        bytes[0x96] = 0x00; bytes[0x97] = 0x20      // characteristics: DLL
        let file = temp.appendingPathComponent("good.dll")
        try Data(bytes).write(to: file)
        XCTAssertTrue(PEFile.isX64DLL(at: file))

        bytes[0x84] = 0x4C; bytes[0x85] = 0x01      // 32-bit
        try Data(bytes).write(to: file)
        XCTAssertFalse(PEFile.isX64DLL(at: file))

        try "<html>404</html>".write(to: file, atomically: true, encoding: .utf8)
        XCTAssertFalse(PEFile.isX64DLL(at: file))
    }
}
