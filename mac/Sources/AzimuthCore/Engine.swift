import Foundation

/// Apple's Game Porting Toolkit: Wine plus D3DMetal, which translates Direct3D 12 to Metal.
public struct Engine: Equatable {
    public let wine64: URL

    public init(wine64: URL) {
        self.wine64 = wine64
    }

    /// `<root>/bin/wine64` has its libraries in `<root>/lib` in both known layouts
    /// (the Gcenx app bundle and Apple's Homebrew build).
    public var root: URL { wine64.deletingLastPathComponent().deletingLastPathComponent() }
    public var binDirectory: URL { wine64.deletingLastPathComponent() }
    public var libDirectory: URL { root.appendingPathComponent("lib", isDirectory: true) }
    public var externalDirectory: URL { libDirectory.appendingPathComponent("external", isDirectory: true) }

    public static let homebrewCaskCommand = "brew install --cask --no-quarantine gcenx/wine/game-porting-toolkit"
    public static let appleDownloadPage = URL(string: "https://developer.apple.com/games/game-porting-toolkit/")!

    public static func defaultCandidates() -> [String] {
        let home = NSHomeDirectory()
        return [
            "/Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine64",
            "\(home)/Applications/Game Porting Toolkit.app/Contents/Resources/wine/bin/wine64",
            "/usr/local/opt/game-porting-toolkit/bin/wine64",
            "/opt/homebrew/opt/game-porting-toolkit/bin/wine64",
        ]
    }

    /// Finds an engine: the user's explicit choice first, then the usual install locations.
    public static func locate(
        preferred: String? = nil,
        candidates: [String] = Engine.defaultCandidates()
    ) -> Engine? {
        let paths = (preferred.map { [$0] } ?? []) + candidates
        guard let found = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return nil
        }
        return Engine(wine64: URL(fileURLWithPath: found))
    }

    // MARK: D3DMetal

    public var d3dMetalFramework: URL { externalDirectory.appendingPathComponent("D3DMetal.framework") }
    public var d3dSharedLibrary: URL { externalDirectory.appendingPathComponent("libd3dshared.dylib") }

    /// D3DMetal ships only in Apple's own download, so the engine installs without it.
    public var hasD3DMetal: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: d3dMetalFramework.path) && fm.fileExists(atPath: d3dSharedLibrary.path)
    }

    public enum D3DMetalError: LocalizedError {
        case redistNotFound(URL)
        case mountFailed(String)

        public var errorDescription: String? {
            switch self {
            case .redistNotFound(let url):
                return "Could not find a redist/lib folder inside \(url.lastPathComponent). "
                    + "Choose the Game Porting Toolkit disk image downloaded from Apple."
            case .mountFailed(let output):
                return "The disk image could not be opened: \(output)"
            }
        }
    }

    /// Looks for Apple's `redist/lib` folder inside `volume`, going at most three levels down.
    public static func findRedistLib(in volume: URL) -> URL? {
        let fm = FileManager.default
        func search(_ dir: URL, depth: Int) -> URL? {
            let direct = dir.appendingPathComponent("redist/lib", isDirectory: true)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: direct.path, isDirectory: &isDir), isDir.boolValue { return direct }
            guard depth > 0,
                  let children = try? fm.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            else { return nil }
            for child in children where (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                if let hit = search(child, depth: depth - 1) { return hit }
            }
            return nil
        }
        return search(volume, depth: 3)
    }

    /// Copies D3DMetal out of Apple's disk image (or an already-mounted volume) into the engine.
    public func installD3DMetal(from source: URL, onOutput: (@Sendable (String) -> Void)? = nil) throws {
        var mountPoint: URL?
        var volume = source

        if source.pathExtension.lowercased() == "dmg" {
            let result = try Shell.run(
                "/usr/bin/hdiutil", ["attach", "-readonly", "-nobrowse", "-plist", source.path])
            guard result.succeeded, let mounted = Engine.mountPoint(fromHdiutilPlist: result.output) else {
                throw D3DMetalError.mountFailed(result.output)
            }
            mountPoint = mounted
            volume = mounted
        }
        defer {
            if let mountPoint {
                _ = try? Shell.run("/usr/bin/hdiutil", ["detach", "-quiet", mountPoint.path])
            }
        }

        guard let redist = Engine.findRedistLib(in: volume) else {
            throw D3DMetalError.redistNotFound(source)
        }
        onOutput?("Copying D3DMetal from \(redist.path)\n")
        try FileManager.default.createDirectory(at: libDirectory, withIntermediateDirectories: true)
        let copy = try Shell.run("/usr/bin/ditto", [redist.path, libDirectory.path], onOutput: onOutput)
        guard copy.succeeded else { throw D3DMetalError.mountFailed(copy.output) }

        // Files copied from a downloaded image carry quarantine flags and an invalid signature
        // inside a re-signed app bundle; clear both so Wine can load them.
        _ = try? Shell.run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", externalDirectory.path])
        for target in [d3dMetalFramework, d3dSharedLibrary] {
            _ = try? Shell.run("/usr/bin/codesign", ["--force", "--deep", "-s", "-", target.path])
        }
    }

    /// Pulls the first `mount-point` out of `hdiutil attach -plist` output.
    static func mountPoint(fromHdiutilPlist output: String) -> URL? {
        guard let data = output.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]]
        else { return nil }
        for entity in entities {
            if let path = entity["mount-point"] as? String { return URL(fileURLWithPath: path) }
        }
        return nil
    }
}
