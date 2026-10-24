#if canImport(SwiftUI)
import AppKit
import AzimuthCore
import SwiftUI
import UniformTypeIdentifiers

enum SetupStep: String, CaseIterable, Identifiable {
    case rosetta, engine, d3dMetal, prefix, compiler, azimuth, gameFolder
    var id: String { rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    let paths = AppPaths()

    @Published var settings: LauncherSettings {
        didSet { try? settings.save(to: paths.settingsFile) }
    }
    @Published private(set) var engine: Engine?
    @Published private(set) var done: Set<SetupStep> = []
    @Published private(set) var busyTitle: String?
    @Published private(set) var console = ""
    @Published private(set) var session: GameSession?
    @Published private(set) var findings: [Finding] = []
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    init() {
        settings = LauncherSettings.load(from: paths.settingsFile)
        refresh()
    }

    var isBusy: Bool { busyTitle != nil }
    var isRunning: Bool { session != nil }
    var setupComplete: Bool { done.count == SetupStep.allCases.count }
    var gameFolderURL: URL? { settings.gameFolder.map { URL(fileURLWithPath: $0) } }

    /// The Azimuth zip inside the app bundle, or beside the repo when run with `swift run`.
    var bundledZip: URL? {
        if let url = Bundle.main.url(forResource: "azimuth-windows", withExtension: "zip") { return url }
        let dev = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("../azimuth-windows.zip").standardized
        return FileManager.default.fileExists(atPath: dev.path) ? dev : nil
    }

    // MARK: State

    func refresh() {
        engine = Engine.locate(preferred: settings.enginePath)
        var next: Set<SetupStep> = []
        if SystemChecks.hasRosetta { next.insert(.rosetta) }
        if let engine {
            next.insert(.engine)
            if engine.hasD3DMetal { next.insert(.d3dMetal) }
            let prefix = Prefix(engine: engine, paths: paths)
            if prefix.isInitialized { next.insert(.prefix) }
            if prefix.hasNativeD3DCompiler { next.insert(.compiler) }
        }
        if AzimuthPackage.isInstalled(at: paths.azimuthDirectory) { next.insert(.azimuth) }
        if let folder = gameFolderURL, GameFolder.check(folder) == .valid { next.insert(.gameFolder) }
        done = next
    }

    func isDone(_ step: SetupStep) -> Bool { done.contains(step) }

    func canRun(_ step: SetupStep) -> Bool {
        guard !isBusy else { return false }
        switch step {
        case .rosetta, .engine, .d3dMetal, .gameFolder: return true
        case .prefix: return engine != nil
        case .compiler: return engine != nil && isDone(.prefix)
        case .azimuth: return isDone(.prefix)
        }
    }

    // MARK: Background work

    private func append(_ text: String) {
        console += text
        if console.count > 60_000 { console = String(console.suffix(40_000)) }
    }

    private var sink: @Sendable (String) -> Void {
        { [weak self] text in Task { @MainActor [weak self] in self?.append(text) } }
    }

    /// Runs blocking work off the main thread, with the console showing its output.
    /// The work receives the console sink; it is `@escaping` because the library's output callbacks are.
    private func perform(
        _ title: String,
        work: @escaping @Sendable (_ output: @escaping @Sendable (String) -> Void) throws -> Void
    ) {
        guard !isBusy else { return }
        busyTitle = title
        console = ""
        let output = sink
        Task.detached {
            let failure: String?
            do {
                try work(output)
                failure = nil
            } catch {
                failure = error.localizedDescription
            }
            await MainActor.run {
                self.busyTitle = nil
                if let failure { self.errorMessage = "\(title) failed. \(failure)" }
                self.refresh()
            }
        }
    }

    private struct StepFailure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: Setup actions

    func installRosetta() {
        perform("Installing Rosetta 2") { output in
            let result = try SystemChecks.installRosetta(onOutput: output)
            if !result.succeeded {
                throw StepFailure(message: "Run this in Terminal instead: "
                    + "sudo softwareupdate --install-rosetta --agree-to-license")
            }
        }
    }

    func installEngine() {
        guard let brew = SystemChecks.brewPath else {
            NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
            infoMessage = "Homebrew is not installed. Install it from brew.sh, then come back and try again, "
                + "or use Locate… if you already have the toolkit."
            return
        }
        perform("Installing Game Porting Toolkit with Homebrew") { output in
            let result = try SystemChecks.installEngine(brew: brew, onOutput: output)
            if !result.succeeded { throw StepFailure(message: "Homebrew reported an error. See the log below.") }
        }
    }

    func locateEngine() {
        let panel = NSOpenPanel()
        panel.message = "Choose the wine64 program inside Game Porting Toolkit"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard url.lastPathComponent == "wine64" else {
            errorMessage = "That file is not wine64. It is in the toolkit's bin folder."
            return
        }
        settings.enginePath = url.path
        refresh()
    }

    func openAppleDownloadPage() { NSWorkspace.shared.open(Engine.appleDownloadPage) }

    func addD3DMetal() {
        guard let engine else { return }
        let panel = NSOpenPanel()
        panel.message = "Choose the Game Porting Toolkit disk image from Apple (or its mounted volume)"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let url = panel.url else { return }
        perform("Installing D3DMetal") { output in
            try engine.installD3DMetal(from: url, onOutput: output)
        }
    }

    func createPrefix() {
        guard let engine else { return }
        let paths = paths
        perform("Creating the Wine prefix") { output in
            try Prefix(engine: engine, paths: paths).initialize(onOutput: output)
        }
    }

    func installCompiler() {
        guard let engine else { return }
        let paths = paths
        perform("Installing the shader compiler") { output in
            try Prefix(engine: engine, paths: paths).installNativeD3DCompiler(onOutput: output)
        }
    }

    func installAzimuth() {
        if let zip = bundledZip {
            installAzimuth(from: zip)
        } else {
            updateAzimuthFromZip()
        }
    }

    func updateAzimuthFromZip() {
        let panel = NSOpenPanel()
        panel.message = "Choose azimuth-windows.zip"
        panel.allowedContentTypes = [.zip]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        installAzimuth(from: url)
    }

    private func installAzimuth(from zip: URL) {
        let destination = paths.azimuthDirectory
        perform("Installing Azimuth") { output in
            output("Unpacking \(zip.lastPathComponent)\n")
            try AzimuthPackage.install(zip: zip, into: destination)
        }
    }

    func chooseGameFolder() {
        let panel = NSOpenPanel()
        panel.message = "Choose the game folder, the one that holds Mount"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        switch GameFolder.check(url) {
        case .valid:
            settings.gameFolder = url.path
        case .useSubfolder(let inner):
            settings.gameFolder = inner.path
            infoMessage = "Using \(inner.lastPathComponent), the folder inside that one that holds Mount."
        case .missingMount:
            errorMessage = "No folder named Mount was found in \(url.lastPathComponent). "
                + "Choose the game folder, the one that contains Mount."
        case .notAFolder:
            errorMessage = "That is not a folder."
        }
        refresh()
    }

    func resetPrefix() {
        guard let engine else { return }
        let paths = paths
        perform("Resetting the Wine prefix") { _ in
            try Prefix(engine: engine, paths: paths).reset()
        }
    }

    // MARK: Play

    func play() {
        guard let engine, let folder = gameFolderURL, !isBusy, !isRunning else { return }
        let paths = paths
        let options = settings.options
        busyTitle = "Starting Azimuth"
        console = ""
        findings = []
        let output = sink

        Task.detached {
            do {
                let prefix = Prefix(engine: engine, paths: paths)
                try prefix.mapGameFolder(folder)
                try IniFile.set("game_folder", to: AppPaths.windowsGameFolder, section: "launcher", in: paths.azimuthIni)
                try prefix.setRetinaMode(options.retinaMode)

                let session = GameSession(engine: engine, paths: paths, options: options)
                session.onOutput = output
                session.onExit = { [weak self] status in
                    Task { @MainActor [weak self] in self?.sessionEnded(status: status) }
                }
                try session.start()
                await MainActor.run {
                    self.session = session
                    self.busyTitle = nil
                }
            } catch {
                await MainActor.run {
                    self.busyTitle = nil
                    self.errorMessage = "Azimuth could not start. \(error.localizedDescription)"
                }
            }
        }
    }

    func stop() { session?.terminate() }

    private func sessionEnded(status: Int32) {
        append("\nAzimuth exited with status \(status).\n")
        findings = Diagnosis.analyze(Diagnosis.collectLogs(paths: paths))
        session = nil
    }

    // MARK: Folders

    func openLogs() { NSWorkspace.shared.open(paths.logs) }

    func showAzimuthFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([paths.azimuthDirectory])
    }
}
#endif
