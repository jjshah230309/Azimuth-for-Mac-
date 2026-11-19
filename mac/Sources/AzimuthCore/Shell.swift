import Foundation

public struct ProcessResult {
    public let status: Int32
    public let output: String
    public var succeeded: Bool { status == 0 }
}

private final class OutputBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}

public enum Shell {
    /// Runs a program to completion, merging stdout and stderr. `onOutput` is called from a
    /// background thread as text arrives.
    @discardableResult
    public static func run(
        _ executable: String,
        _ arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment { process.environment = environment }
        if let currentDirectory { process.currentDirectoryURL = currentDirectory }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let box = OutputBox()

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            box.append(chunk)
            onOutput?(String(decoding: chunk, as: UTF8.self))
        }

        try process.run()
        process.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil

        let rest = pipe.fileHandleForReading.readDataToEndOfFile()
        if !rest.isEmpty {
            box.append(rest)
            onOutput?(String(decoding: rest, as: UTF8.self))
        }
        return ProcessResult(status: process.terminationStatus, output: box.text)
    }

    /// Absolute path of the first existing file among `candidates`.
    public static func firstExisting(_ candidates: [String]) -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
