#if canImport(SwiftUI)
import AzimuthCore
import SwiftUI

struct SetupView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Get ready to play")
                        .font(.title2.bold())
                    Text("Each step turns green when it is done. Azimuth runs through Apple's Game Porting Toolkit, "
                        + "which this app sets up for you.")
                        .foregroundStyle(.secondary)

                    ForEach(SetupStep.allCases) { step in
                        StepRow(step: step)
                    }
                }
                .padding(20)
            }
            ConsoleView()
        }
    }
}

private struct StepRow: View {
    @EnvironmentObject var model: AppModel
    let step: SetupStep

    private var info: (title: String, detail: String) {
        switch step {
        case .rosetta:
            return ("Rosetta 2", "Lets this Apple Silicon Mac run the Intel-only toolkit.")
        case .engine:
            return ("Game Porting Toolkit", model.engine.map { "Found at \($0.root.path)" }
                ?? "Wine plus Apple's Direct3D-to-Metal layer. Installed with Homebrew.")
        case .d3dMetal:
            return ("D3DMetal", "Apple's graphics layer. It is only in Apple's own download (free Apple ID), "
                + "so you add it from the disk image you download.")
        case .prefix:
            return ("Wine prefix", "A private Windows environment for Azimuth, kept in Application Support.")
        case .compiler:
            return ("Shader compiler", "Microsoft's d3dcompiler_47.dll, which Azimuth uses. Downloaded once.")
        case .azimuth:
            return ("Azimuth", model.bundledZip == nil
                ? "Choose azimuth-windows.zip to install it."
                : "Installs the Windows build bundled with this app.")
        case .gameFolder:
            return ("Game folder", model.settings.gameFolder
                ?? "The folder that contains Mount, from your own copy of the game.")
        }
    }

    var body: some View {
        let done = model.isDone(step)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(done ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(info.title).font(.headline)
                Text(info.detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            HStack {
                actions(done: done)
            }
            .disabled(!model.canRun(step))
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func actions(done: Bool) -> some View {
        switch step {
        case .rosetta:
            if !done { Button("Install") { model.installRosetta() } }
        case .engine:
            if !done { Button("Install") { model.installEngine() } }
            Button("Locate…") { model.locateEngine() }
        case .d3dMetal:
            if !done { Button("Download from Apple") { model.openAppleDownloadPage() } }
            Button(done ? "Replace…" : "Add from disk image…") { model.addD3DMetal() }
                .disabled(model.engine == nil)
        case .prefix:
            if !done { Button("Create") { model.createPrefix() } }
        case .compiler:
            if !done { Button("Install") { model.installCompiler() } }
        case .azimuth:
            Button(done ? "Update from zip…" : "Install") {
                done ? model.updateAzimuthFromZip() : model.installAzimuth()
            }
        case .gameFolder:
            Button(done ? "Change…" : "Choose…") { model.chooseGameFolder() }
        }
    }
}

struct ConsoleView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let title = model.busyTitle {
                    ProgressView().controlSize(.small)
                    Text(title).font(.callout.bold())
                } else {
                    Text("Log").font(.callout.bold()).foregroundStyle(.secondary)
                }
                Spacer()
            }
            ScrollViewReader { proxy in
                ScrollView {
                    Text(model.console.isEmpty ? " " : model.console)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("end")
                }
                .onChange(of: model.console) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
            }
            .frame(height: 140)
            .padding(6)
            .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding([.horizontal, .bottom], 20)
        .padding(.top, 8)
    }
}
#endif
