import SwiftUI
import PerformanceProfiler
import ProfilerUI

@main
struct TestApp: App {

    /// One profiler for the whole app lifetime.
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView(profiler: store.profiler)
                .task { await store.profiler.start() }
        }
    }
}

/// Holds shared state so the profiler survives view re-creation.
final class AppStore: ObservableObject {
    let profiler = PerformanceProfiler()
}
