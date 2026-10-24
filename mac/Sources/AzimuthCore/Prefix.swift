import Foundation

/// The Wine prefix Azimuth runs in: a private C: drive and registry under Application Support.
public struct Prefix {
    public let engine: Engine
    public let paths: AppPaths

    public init(engine: Engine, paths: AppPaths) {
        self.engine = engine
        self.paths = paths
    }

    /// Microsoft's Direct3D shader compiler (x64), the build winetricks uses.
    public static let d3dCompilerURL =
        "https://raw.githubusercontent.com/mozilla/fxc2/master/dll/d3dcompiler_47.dll"

    /// Set to a sha256 to make the download fail unless it matches exactly. Left unset until a
    /// hash has been confirmed against a copy fetched on a Mac; the PE check below still applies.
    public static let d3dCompilerSHA256: String? = nil

    /// Wine's own d3dcompiler_47 is a small stub; Microsoft's is over 4 MB.
    static let nativeCompilerMinimumBytes = 1_000_000

    public enum PrefixError: LocalizedError {
        case wineFailed(String)
        case downloadFailed(String)
        case notADLL
        case hashMismatch(expected: String, actual: String)

        public var errorDescription: String? {
            switch self {
            case .wineFailed(let output): return "Wine reported an error: \(output)"
            case .downloadFailed(let output): return "The download failed: \(output)"
            case .notADLL: return "The downloaded file is not a 64-bit Windows DLL."
            case .hashMismatch(let expected, let actual):
                return "The download did not match its expected checksum (\(expected), got \(actual))."
            }
        }
    }

    public var isInitialized: Bool {
        FileManager.default.fileExists(atPath: paths.prefix.appendingPathComponent("system.reg").path)
    }

    public var hasNativeD3DCompiler: Bool {
        let file = paths.system32.appendingPathComponent("d3dcompiler_47.dll")
        let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
        return size >= Prefix.nativeCompilerMinimumBytes
    }

    // MARK: Wine

    @discardableResult
    func wine(
        _ arguments: [String],
        overrides: String = WineEnvironment.azimuthOverrides,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) throws -> ProcessResult {
        let env = WineEnvironment.make(engine: engine, paths: paths, overrides: overrides)
        return try Shell.run(engine.wine64.path, arguments, environment: env, onOutput: onOutput)
    }

    /// Creates the prefix and sets it to behave like Windows 10.
    public func initialize(onOutput: (@Sendable (String) -> Void)? = nil) throws {
        try paths.ensureDirectories()
        try FileManager.default.createDirectory(at: paths.prefix, withIntermediateDirectories: true)

        let boot = try wine(["wineboot", "--init"],
                            overrides: WineEnvironment.prefixCreationOverrides, onOutput: onOutput)
        guard boot.succeeded, isInitialized else { throw PrefixError.wineFailed(boot.output) }

        // Wait for wineserver so the registry is flushed before the next command.
        _ = try? wine(["wineboot", "--end-session"], overrides: WineEnvironment.prefixCreationOverrides)
        let version = try wine(["winecfg", "-v", "win10"], onOutput: onOutput)
        guard version.succeeded else { throw PrefixError.wineFailed(version.output) }
    }

    /// Wine's `HKCU\Software\Wine\Mac Driver\RetinaMode`.
    public func setRetinaMode(_ enabled: Bool) throws {
        let result = try wine([
            "reg", "add", "HKEY_CURRENT_USER\\Software\\Wine\\Mac Driver",
            "/v", "RetinaMode", "/t", "REG_SZ", "/d", enabled ? "y" : "n", "/f",
        ])
        guard result.succeeded else { throw PrefixError.wineFailed(result.output) }
    }

    // MARK: Shader compiler

    /// Installs Microsoft's d3dcompiler_47.dll from `file`, or downloads it when `file` is nil.
    public func installNativeD3DCompiler(
        from file: URL? = nil,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) throws {
        let fm = FileManager.default
        var source = file
        var downloaded: URL?

        if source == nil {
            let target = fm.temporaryDirectory.appendingPathComponent("d3dcompiler_47-\(UUID().uuidString).dll")
            onOutput?("Downloading d3dcompiler_47.dll\n")
            let curl = try Shell.run("/usr/bin/curl", ["-fsSL", "--retry", "3", "-o", target.path, Prefix.d3dCompilerURL])
            guard curl.succeeded else { throw PrefixError.downloadFailed(curl.output) }
            source = target
            downloaded = target
        }
        defer { if let downloaded { try? fm.removeItem(at: downloaded) } }

        guard let dll = source, PEFile.isX64DLL(at: dll) else { throw PrefixError.notADLL }

        if let expected = Prefix.d3dCompilerSHA256 {
            let sum = try Shell.run("/usr/bin/shasum", ["-a", "256", dll.path])
            let actual = sum.output.split(separator: " ").first.map(String.init) ?? ""
            guard actual.lowercased() == expected.lowercased() else {
                throw PrefixError.hashMismatch(expected: expected, actual: actual)
            }
        }

        try fm.createDirectory(at: paths.system32, withIntermediateDirectories: true)
        let destination = paths.system32.appendingPathComponent("d3dcompiler_47.dll")
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.copyItem(at: dll, to: destination)
    }

    // MARK: Game folder

    /// Makes the user's game folder appear to Windows as `G:\`, a short path (Azimuth warns about long ones).
    public func mapGameFolder(_ folder: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: paths.dosDevices, withIntermediateDirectories: true)
        let link = paths.dosDevices.appendingPathComponent("\(AppPaths.gameDriveLetter):")
        if (try? fm.destinationOfSymbolicLink(atPath: link.path)) != nil || fm.fileExists(atPath: link.path) {
            try fm.removeItem(at: link)
        }
        try fm.createSymbolicLink(atPath: link.path, withDestinationPath: folder.path)
    }

    // MARK: Reset

    public func reset() throws {
        if FileManager.default.fileExists(atPath: paths.prefix.path) {
            _ = try? wine(["wineboot", "--kill"], overrides: WineEnvironment.prefixCreationOverrides)
            try FileManager.default.removeItem(at: paths.prefix)
        }
    }
}
