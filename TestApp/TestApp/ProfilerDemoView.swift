import SwiftUI
import PerformanceProfiler
import ProfilerUI

/// Demonstrates ProfilerOverlayWindow (app-wide UIKit overlay) and trace export.
struct ProfilerDemoView: View {

    let profiler: PerformanceProfiler
    @State private var exportedJSON: String?
    @State private var showExport = false

    var body: some View {
        NavigationStack {
            List {
                Section("Floating Overlay") {
                    Text("The draggable HUD in the top-left corner is a ")
                    + Text("ProfilerOverlayView").bold()
                    + Text(" embedded in ContentView. Tap its chevron ›› to expand sparklines.")
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                Section("App-Wide Window (UIKit)") {
                    Text("ProfilerOverlayWindow.install(in: windowScene) floats the HUD above every modal and alert — call it once in your SceneDelegate.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Button("Install window overlay") {
                        if let scene = UIApplication.shared.connectedScenes
                            .compactMap({ $0 as? UIWindowScene }).first {
                            ProfilerOverlayWindow.install(in: scene)
                        }
                    }

                    Button("Remove window overlay", role: .destructive) {
                        ProfilerOverlayWindow.remove()
                    }
                }

                Section("Trace Export") {
                    Button("Export current trace to JSON") {
                        let trace = profiler.currentTrace()
                        if let data = try? TraceExporter.exportJSON(trace),
                           let json = String(data: data, encoding: .utf8) {
                            exportedJSON = json
                            showExport = true
                        }
                    }
                }

                Section("Configuration Presets") {
                    LabeledContent("Default")        { Text("100 ms · FPS on") }
                    LabeledContent(".lightweight")   { Text("1 s · FPS off") }
                    LabeledContent(".highFrequency") { Text("33 ms · FPS on") }
                }
            }
            .navigationTitle("PerformanceProfiler")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showExport) {
            NavigationStack {
                ScrollView {
                    Text(exportedJSON ?? "")
                        .font(.system(.caption2, design: .monospaced))
                        .padding()
                }
                .navigationTitle("Trace JSON")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showExport = false }
                    }
                }
            }
        }
    }
}

#Preview {
    ProfilerDemoView(profiler: PerformanceProfiler())
}
