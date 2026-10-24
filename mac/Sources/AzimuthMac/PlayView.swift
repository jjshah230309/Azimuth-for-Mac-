#if canImport(SwiftUI)
import AzimuthCore
import SwiftUI

struct PlayView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    optionsBox
                    if !model.findings.isEmpty { findingsBox }
                }
                .padding(20)
            }
            ConsoleView()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Azimuth").font(.largeTitle.bold())
                Text(model.settings.gameFolder ?? "No game folder")
                    .font(.callout).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if model.isRunning {
                Button(role: .destructive) { model.stop() } label: {
                    Label("Stop", systemImage: "stop.fill").frame(minWidth: 90)
                }
                .controlSize(.large)
            } else {
                Button { model.play() } label: {
                    Label("Play", systemImage: "play.fill").frame(minWidth: 90)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(model.isBusy || !model.setupComplete)
            }
        }
    }

    private var optionsBox: some View {
        GroupBox("Options") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Skip Azimuth's launcher window", isOn: $model.settings.options.skipAzimuthLauncher)
                Toggle("Retina resolution (sharper, heavier)", isOn: $model.settings.options.retinaMode)
                Toggle("Report AVX support to the game", isOn: $model.settings.options.advertiseAVX)
                Toggle("Show Metal performance overlay", isOn: $model.settings.options.metalHUD)
                Toggle("Detailed logs", isOn: $model.settings.options.verboseLogs)
            }
            .disabled(model.isRunning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
    }

    private var findingsBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("What went wrong", systemImage: "exclamationmark.triangle.fill")
                .font(.headline).foregroundStyle(.orange)
            ForEach(Array(model.findings.enumerated()), id: \.offset) { _, finding in
                VStack(alignment: .leading, spacing: 4) {
                    Text(finding.title).font(.subheadline.bold())
                    Text(finding.detail).font(.callout).foregroundStyle(.secondary)
                    Text(finding.remedy).font(.callout)
                }
            }
            Button("Open Logs Folder") { model.openLogs() }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}
#endif
