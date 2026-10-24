import Foundation

/// Everything the app writes lives under one folder, so "Reset" is a single delete.
public struct AppPaths {
    public let root: URL

    public init(root: URL = AppPaths.defaultRoot) {
        self.root = root
    }

    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Azimuth for Mac", isDirectory: true)
    }

    /// The Wine prefix: a private fake C: drive and registry for Azimuth.
    public var prefix: URL { root.appendingPathComponent("prefix", isDirectory: true) }
    public var logs: URL { root.appendingPathComponent("logs", isDirectory: true) }
    public var settingsFile: URL { root.appendingPathComponent("launcher.json") }

    /// Where Azimuth is installed, seen from Windows as `C:\Azimuth`.
    public var azimuthDirectory: URL {
        prefix.appendingPathComponent("drive_c/Azimuth", isDirectory: true)
    }
    public var azimuthExecutable: URL { azimuthDirectory.appendingPathComponent("azimuth.exe") }
    public var azimuthIni: URL { azimuthDirectory.appendingPathComponent("azimuth.ini") }
    public var azimuthLog: URL { azimuthDirectory.appendingPathComponent("azimuth.log") }

    public var system32: URL {
        prefix.appendingPathComponent("drive_c/windows/system32", isDirectory: true)
    }
    public var dosDevices: URL { prefix.appendingPathComponent("dosdevices", isDirectory: true) }

    /// Windows drive letter that points at the user's game folder.
    public static let gameDriveLetter = "g"
    public static let windowsGameFolder = "G:\\"
    public static let windowsExecutable = "C:\\Azimuth\\azimuth.exe"

    public func ensureDirectories() throws {
        for url in [root, logs] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
