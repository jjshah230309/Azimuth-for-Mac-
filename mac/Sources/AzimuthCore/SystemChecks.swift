import Foundation

/// Things outside the app that setup depends on.
public enum SystemChecks {
    /// Rosetta 2 translates the Intel-only Wine build on Apple Silicon.
    public static var hasRosetta: Bool {
        FileManager.default.fileExists(atPath: "/Library/Apple/usr/share/rosetta/rosetta")
    }

    public static var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    public static func installRosetta(onOutput: (@Sendable (String) -> Void)? = nil) throws -> ProcessResult {
        try Shell.run("/usr/sbin/softwareupdate", ["--install-rosetta", "--agree-to-license"], onOutput: onOutput)
    }

    public static var brewPath: String? {
        Shell.firstExisting(["/opt/homebrew/bin/brew", "/usr/local/bin/brew"])
    }

    /// Installs Gcenx's build of Apple's Game Porting Toolkit through Homebrew.
    public static func installEngine(brew: String, onOutput: (@Sendable (String) -> Void)? = nil) throws -> ProcessResult {
        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        return try Shell.run(
            brew, ["install", "--cask", "--no-quarantine", "gcenx/wine/game-porting-toolkit"],
            environment: env, onOutput: onOutput)
    }
}
