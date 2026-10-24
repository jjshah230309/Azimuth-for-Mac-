import Foundation

/// One run of Azimuth under Wine. Output is shown live and also written to `logs/session-<time>.log`.
public final class GameSession: @unchecked Sendable {
    public let engine: Engine
    public let paths: AppPaths
    public let options: LaunchOptions
    public let logFile: URL

    public var onOutput: (@Sendable (String) -> Void)?
    public var onExit: (@Sendable (Int32) -> Void)?

    private let lock = NSLock()
    private var process: Process?
    private var logHandle: FileHandle?

    public init(engine: Engine, paths: AppPaths, options: LaunchOptions) {
        self.engine = engine
        self.paths = paths
        self.options = options
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        self.logFile = paths.logs.appendingPathComponent("session-\(stamp).log")
    }

    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return process?.isRunning ?? false
    }

    public func start() throws {
        try paths.ensureDirectories()
        _ = FileManager.default.createFile(atPath: logFile.path, contents: nil)
        let handle = try FileHandle(forWritingTo: logFile)

        let process = Process()
        process.executableURL = engine.wine64
        process.arguments = WineEnvironment.azimuthArguments(options: options)
        process.currentDirectoryURL = paths.azimuthDirectory
        process.environment = WineEnvironment.make(engine: engine, paths: paths, options: options)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] source in
            let chunk = source.availableData
            guard !chunk.isEmpty, let self else { return }
            self.write(chunk)
        }
        process.terminationHandler = { [weak self] finished in
            guard let self else { return }
            pipe.fileHandleForReading.readabilityHandler = nil
            let rest = pipe.fileHandleForReading.readDataToEndOfFile()
            if !rest.isEmpty { self.write(rest) }
            self.lock.lock()
            try? self.logHandle?.close()
            self.logHandle = nil
            self.lock.unlock()
            self.onExit?(finished.terminationStatus)
        }

        lock.lock()
        self.process = process
        self.logHandle = handle
        lock.unlock()

        do {
            try process.run()
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            try? handle.close()
            throw error
        }
    }

    /// Stops Azimuth and everything Wine started for it.
    public func terminate() {
        lock.lock()
        let running = process
        lock.unlock()
        running?.terminate()
        _ = try? Shell.run(
            engine.binDirectory.appendingPathComponent("wineserver").path, ["-k"],
            environment: WineEnvironment.make(engine: engine, paths: paths, options: options))
    }

    private func write(_ chunk: Data) {
        lock.lock()
        try? logHandle?.write(contentsOf: chunk)
        lock.unlock()
        onOutput?(String(decoding: chunk, as: UTF8.self))
    }
}
