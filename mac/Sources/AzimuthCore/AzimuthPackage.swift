import Foundation

/// Installs the Windows build of Azimuth (`azimuth-windows.zip`) into the Wine prefix.
public enum AzimuthPackage {
    /// Files Azimuth cannot start without; `azimuth.exe` loads the rest from `data/bin`.
    public static let requiredFiles = [
        "azimuth.exe",
        "data/bin/azimuth.pipelines",
        "data/bin/azimuth-tls.dll",
        "data/bin/avcodec-62.dll",
        "data/bin/avutil-60.dll",
        "data/bin/msvcr110.dll",
        "data/bin/msvcp110.dll",
    ]

    public enum PackageError: LocalizedError {
        case extractionFailed(String)
        case incomplete(missing: [String])

        public var errorDescription: String? {
            switch self {
            case .extractionFailed(let output):
                return "The Azimuth zip could not be unpacked: \(output)"
            case .incomplete(let missing):
                return "This does not look like the Azimuth Windows build. Missing: "
                    + missing.joined(separator: ", ")
            }
        }
    }

    public static func missingFiles(in root: URL) -> [String] {
        requiredFiles.filter { !FileManager.default.fileExists(atPath: root.appendingPathComponent($0).path) }
    }

    public static func isInstalled(at directory: URL) -> Bool {
        missingFiles(in: directory).isEmpty
    }

    /// The folder holding `azimuth.exe`: `dir` itself or one of its direct subfolders
    /// (the zip wraps everything in `azimuth-windows/`).
    public static func findRoot(in dir: URL) -> URL? {
        let fm = FileManager.default
        if fm.fileExists(atPath: dir.appendingPathComponent("azimuth.exe").path) { return dir }
        let children = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return children
            .filter { $0.lastPathComponent != "__MACOSX" }
            .first { fm.fileExists(atPath: $0.appendingPathComponent("azimuth.exe").path) }
    }

    /// Unpacks `zip`, checks it, and copies it over `destination`. Files already in `destination`
    /// that the zip does not contain (azimuth.ini, saves, logs) are kept.
    public static func install(zip: URL, into destination: URL) throws {
        let fm = FileManager.default
        let scratch = fm.temporaryDirectory.appendingPathComponent("azimuth-unpack-\(UUID().uuidString)")
        try fm.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: scratch) }

        // unzip exits 1 for warnings (for example Mac metadata entries); only 2 and up are failures.
        let result = try Shell.run("/usr/bin/unzip", ["-q", "-o", zip.path, "-x", "__MACOSX/*", "-d", scratch.path])
        guard result.status <= 1 else { throw PackageError.extractionFailed(result.output) }

        try install(unpackedAt: scratch, into: destination)
    }

    /// The part of `install(zip:into:)` after extraction, separate so it can be tested without a zip.
    public static func install(unpackedAt directory: URL, into destination: URL) throws {
        guard let root = findRoot(in: directory) else {
            throw PackageError.incomplete(missing: ["azimuth.exe"])
        }
        let missing = missingFiles(in: root)
        guard missing.isEmpty else { throw PackageError.incomplete(missing: missing) }
        try merge(from: root, to: destination)
    }

    static func merge(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        for item in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey]) {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            if try item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                try merge(from: item, to: target)
            } else {
                if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
                try fm.copyItem(at: item, to: target)
            }
        }
    }
}
