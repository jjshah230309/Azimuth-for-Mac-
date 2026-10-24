import Foundation

public struct Finding: Equatable {
    public let title: String
    public let detail: String
    public let remedy: String
}

/// Turns Azimuth's own log lines and Wine's error output into a plain-English cause and next step.
/// The match strings are messages that appear in `azimuth.exe` itself.
public enum Diagnosis {
    private struct Rule {
        let needles: [String]
        let finding: Finding
    }

    private static let rules: [Rule] = [
        Rule(
            needles: ["cannot open heaps over existing memory"],
            finding: Finding(
                title: "Direct3D 12 on this Mac cannot open heaps over existing memory",
                detail: "Azimuth places graphics resources over the Xbox game's own memory using "
                    + "ID3D12Device3::OpenExistingHeapFromAddress. Apple's D3DMetal layer must provide it.",
                remedy: "This is a limit of the installed Game Porting Toolkit, not of the launcher. "
                    + "Install the newest toolkit and D3DMetal, and send azimuth.log to Almost There Games.")),
        Rule(
            needles: ["resource binding tier is below 3"],
            finding: Finding(
                title: "Direct3D 12 resource binding tier 3 is not available",
                detail: "Azimuth needs tier 3 resource binding, and D3DMetal reported less.",
                remedy: "Install the newest Game Porting Toolkit and D3DMetal. If it persists, "
                    + "this Mac's GPU layer cannot run Azimuth yet.")),
        Rule(
            needles: ["D3D12CreateDevice (feature level 11_0", "no DXGI adapter"],
            finding: Finding(
                title: "A Direct3D 12 device could not be created",
                detail: "Azimuth could not get a graphics adapter from Wine.",
                remedy: "Check the setup list: D3DMetal must be installed into the engine. "
                    + "Direct3D 12 also needs macOS 14 or later on Apple Silicon.")),
        Rule(
            needles: ["Library d3d12.dll", "Library dxgi.dll"],
            finding: Finding(
                title: "Wine could not load Direct3D 12",
                detail: "d3d12.dll or dxgi.dll was not found, which means D3DMetal is not in the engine.",
                remedy: "Use \"Add from disk image…\" in setup with the Game Porting Toolkit download from Apple.")),
        Rule(
            needles: ["Private VC11 runtime was overridden", "runtime hash mismatch", "Cannot load desktop dependency"],
            finding: Finding(
                title: "Azimuth's private Visual C++ runtime did not load",
                detail: "Azimuth checks the msvcr110/msvcp110 files beside it and refuses substitutes.",
                remedy: "Reset the Wine prefix from the menu, then let setup install Azimuth again.")),
        Rule(
            needles: ["did not load: error="],
            finding: Finding(
                title: "A file Azimuth needs did not load",
                detail: "One of the DLLs in Azimuth's data/bin folder is missing or damaged.",
                remedy: "Use \"Update Azimuth from Zip…\" with a fresh azimuth-windows.zip.")),
        Rule(
            needles: ["Your processor is not supported"],
            finding: Finding(
                title: "Azimuth rejected the processor",
                detail: "Azimuth checks for modern CPU features. Under Rosetta 2, AVX must be switched on.",
                remedy: "Turn on \"Report AVX support\" in the options and start again.")),
        Rule(
            needles: ["A game file is damaged or missing", "no game to start"],
            finding: Finding(
                title: "Azimuth could not find the game",
                detail: "The game folder is not set, or it is not the folder that holds Mount.",
                remedy: "Choose the game folder again. It is the one that contains a folder named Mount.")),
        Rule(
            needles: ["page fault at GPU address", "D3D12 device removed", "The graphics driver stopped responding"],
            finding: Finding(
                title: "The graphics layer stopped responding",
                detail: "The GPU work was dropped part-way, so the game could not continue.",
                remedy: "Lower Resolution or Antialiasing in Azimuth's Graphics settings and try again.")),
        Rule(
            needles: ["The PC ran out of memory", "out of memory:"],
            finding: Finding(
                title: "The Mac ran out of memory",
                detail: "Azimuth maps large amounts of memory and needs plenty of free RAM.",
                remedy: "Quit other apps and try again. 16 GB of memory is the practical minimum.")),
        Rule(
            needles: ["Your save could not be written", "the save thread failed"],
            finding: Finding(
                title: "Saves could not be written",
                detail: "Azimuth could not write to its saves folder.",
                remedy: "Check free disk space, and that nothing else has the Azimuth folder open.")),
        Rule(
            needles: ["The game used something Azimuth does not support yet"],
            finding: Finding(
                title: "The game used a feature Azimuth does not support yet",
                detail: "Azimuth stopped on purpose when the game asked for something it cannot emulate.",
                remedy: "Send azimuth.log to Almost There Games so they can add support.")),
        Rule(
            needles: ["Unhandled exception", "wine: Unhandled"],
            finding: Finding(
                title: "The program crashed",
                detail: "Wine reported an unhandled exception.",
                remedy: "Turn on verbose logs, run again, and send the log to Almost There Games.")),
    ]

    public static func analyze(_ log: String) -> [Finding] {
        rules.filter { rule in rule.needles.contains { log.localizedCaseInsensitiveContains($0) } }
            .map(\.finding)
    }

    /// The most recent session log plus Azimuth's own log, tails only so large logs stay cheap.
    public static func collectLogs(paths: AppPaths, maxBytes: Int = 400_000) -> String {
        var chunks: [String] = []
        if let session = newestSessionLog(in: paths.logs) { chunks.append(tail(of: session, maxBytes: maxBytes)) }
        chunks.append(tail(of: paths.azimuthLog, maxBytes: maxBytes))
        return chunks.joined(separator: "\n")
    }

    public static func newestSessionLog(in directory: URL) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files
            .filter { $0.pathExtension == "log" }
            .max {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return a < b
            }
    }

    static func tail(of file: URL, maxBytes: Int) -> String {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return "" }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try? handle.seek(toOffset: start)
        return String(decoding: (try? handle.readToEnd()) ?? Data(), as: UTF8.self)
    }
}
