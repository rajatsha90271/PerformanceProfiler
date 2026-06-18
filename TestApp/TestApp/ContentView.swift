import SwiftUI
import PerformanceProfiler
import ProfilerUI

struct ContentView: View {

    let profiler: PerformanceProfiler

    var body: some View {
        TabView {
            ProfilerDemoView(profiler: profiler)
                .tabItem { Label("Overlay", systemImage: "cpu") }

            MetricsDemoView(profiler: profiler)
                .tabItem { Label("Raw Metrics", systemImage: "chart.xyaxis.line") }
        }
        // The floating HUD sits above every tab — drag it anywhere on screen.
        .overlay(alignment: .topLeading) {
            ProfilerOverlayView(profiler: profiler)
                .padding(12)
        }
    }
}

#Preview {
    ContentView(profiler: PerformanceProfiler())
}
