import Foundation

public enum WineEnvironment {
    /// Azimuth hash-checks its own VC11 runtime and wants Microsoft's shader compiler, so Wine's
    /// built-in versions of these three DLLs must not be used.
    public static let azimuthOverrides = "msvcr110,msvcp110,d3dcompiler_47=n"

    /// Skips the Mono and Gecko download prompts while the prefix is created.
    public static let prefixCreationOverrides = "mscoree,mshtml="

    public static func make(
        engine: Engine,
        paths: AppPaths,
        options: LaunchOptions = LaunchOptions(),
        overrides: String = azimuthOverrides,
        base: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var env = base
        env["WINEPREFIX"] = paths.prefix.path
        env["WINEDLLOVERRIDES"] = overrides
        env["WINEDEBUG"] = options.verboseLogs ? "fixme-all,+seh,+loaddll" : "fixme-all"
        env["WINEMSYNC"] = "1"
        env["WINEESYNC"] = "1"
        env["PATH"] = engine.binDirectory.path + ":" + (base["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        if options.advertiseAVX { env["ROSETTA_ADVERTISE_AVX"] = "1" }
        if options.metalHUD { env["MTL_HUD_ENABLED"] = "1" }
        return env
    }

    /// Azimuth's command line, as Windows sees it.
    public static func azimuthArguments(options: LaunchOptions) -> [String] {
        [AppPaths.windowsExecutable] + (options.skipAzimuthLauncher ? ["--skip-launcher"] : [])
    }
}
