import SwiftUI
import Combine
import PerformanceProfiler

/// Shows live MetricSample values from the Combine publisher —
/// raw SDK usage with no ProfilerUI dependency.
struct MetricsDemoView: View {

    let profiler: PerformanceProfiler

    @State private var latest: MetricSample?
    @State private var history: [MetricSample] = []
    @State private var cancellable: AnyCancellable?

    var body: some View {
        NavigationStack {
            List {
                if let s = latest {
                    Section("Live Sample") {
                        metricRow("CPU",     value: String(format: "%.1f %%", s.cpuUsage * 100))
                        metricRow("Memory",  value: String(format: "%.1f MB", s.memoryMB))
                        metricRow("FPS",     value: s.fps > 0 ? String(format: "%.0f fps", s.fps) : "—")
                        metricRow("Thermal", value: s.thermalState.description)
                    }
                } else {
                    Section {
                        Text("Waiting for first sample…")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("History (\(history.count))") {
                    ForEach(history.indices.reversed(), id: \.self) { i in
                        let s = history[i]
                        HStack {
                            Text(String(format: "%.2f s", s.timestamp))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 72, alignment: .leading)
                            Text(String(format: "CPU %.0f%%  MEM %.0f MB  FPS %.0f",
                                        s.cpuUsage * 100, s.memoryMB, s.fps))
                                .font(.system(.caption2, design: .monospaced))
                        }
                    }
                }
            }
            .navigationTitle("Raw Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { history.removeAll() }
                }
            }
        }
        .onAppear {
            cancellable = profiler.samplePublisher
                .receive(on: DispatchQueue.main)
                .sink { sample in
                    latest = sample
                    history.append(sample)
                    if history.count > 120 { history.removeFirst() }
                }
        }
        .onDisappear {
            cancellable = nil
        }
    }

    private func metricRow(_ label: String, value: String) -> some View {
        LabeledContent(label) {
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

#Preview {
    MetricsDemoView(profiler: PerformanceProfiler())
}
