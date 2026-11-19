import Foundation

/// Options chosen on the Play screen. Persisted to `launcher.json`.
public struct LaunchOptions: Codable, Equatable {
    /// Start the game directly instead of showing Azimuth's own launcher window.
    public var skipAzimuthLauncher = false
    /// Render at the Mac's native pixel density (sharper, heavier).
    public var retinaMode = true
    /// Show Apple's Metal performance overlay.
    public var metalHUD = false
    /// Tell Rosetta 2 to report AVX support (Azimuth checks CPU features).
    public var advertiseAVX = true
    /// Log Wine errors and exceptions in more detail.
    public var verboseLogs = false

    public init() {}
}

public struct LauncherSettings: Codable, Equatable {
    public var gameFolder: String?
    public var enginePath: String?
    public var options = LaunchOptions()

    public init() {}

    public static func load(from url: URL) -> LauncherSettings {
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(LauncherSettings.self, from: data)
        else { return LauncherSettings() }
        return settings
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
