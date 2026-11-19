#if canImport(SwiftUI)
import AppKit
import SwiftUI

@main
struct AzimuthMacApp: App {
    @StateObject private var model = AppModel()

    init() {
        // Lets `swift run` show a window and a Dock icon the same way the packaged app does.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("Azimuth for Mac") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 620, minHeight: 640)
                .alert("Something needs attention", isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } })
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(model.errorMessage ?? "")
                }
                .alert("Note", isPresented: Binding(
                    get: { model.infoMessage != nil },
                    set: { if !$0 { model.infoMessage = nil } })
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(model.infoMessage ?? "")
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Logs Folder") { model.openLogs() }
                Button("Show Azimuth Folder") { model.showAzimuthFolder() }
                Divider()
                Button("Update Azimuth from Zip…") { model.updateAzimuthFromZip() }
                    .disabled(!model.canRun(.azimuth))
                Button("Reset Wine Prefix") { model.resetPrefix() }
                    .disabled(model.isBusy || model.isRunning || model.engine == nil)
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var tab: Tab = .setup

    enum Tab: String, CaseIterable, Identifiable {
        case play = "Play", setup = "Setup"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .padding(.top, 12)

            switch tab {
            case .play: PlayView()
            case .setup: SetupView()
            }
        }
        .onAppear { if model.setupComplete { tab = .play } }
        .onChange(of: model.setupComplete) { _, complete in if complete { tab = .play } }
    }
}
#else
import Foundation

@main
struct AzimuthMacUnsupported {
    static func main() {
        print("Azimuth for Mac needs macOS. The AzimuthCore library builds anywhere.")
    }
}
#endif
