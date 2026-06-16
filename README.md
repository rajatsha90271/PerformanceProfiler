# PerformanceProfiler

A lightweight Swift SDK for real-time CPU, memory, FPS, and thermal monitoring on iOS. Drop it into any app to get live metrics via Combine publishers or a floating SwiftUI overlay — no Instruments required.

---

## Features

- **CPU usage** — per-sample percentage across all cores
- **Memory** — resident memory in MB
- **FPS** — frame rate via `CADisplayLink`
- **Thermal state** — nominal / fair / serious / critical
- **Combine publisher** — stream `MetricSample` values at a configurable interval
- **SwiftUI overlay** — draggable floating HUD with mini sparkline graphs
- **JSON export** — serialize a full trace to disk or send to a backend
- **Ring buffer storage** — bounded memory usage, oldest samples dropped automatically

---

## Requirements

- iOS 16+
- Swift 5.9+
- Xcode 15+

---

## Installation

### Swift Package Manager

Add the package in **Xcode → File → Add Package Dependencies** and enter:

```
https://github.com/rajatsha90271/PerformanceProfiler
```

Or add it manually to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rajatsha90271/PerformanceProfiler.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "PerformanceProfiler", package: "PerformanceProfiler"),
            .product(name: "ProfilerUI", package: "PerformanceProfiler"), // optional, for SwiftUI overlay
        ]
    )
]
```

---

## Quick Start

### 1. Start and stop the profiler

```swift
import PerformanceProfiler

let profiler = PerformanceProfiler()

// Start sampling (call on MainActor)
await profiler.start()

// Stop and get the full trace
let trace = await profiler.stop()
```

### 2. Subscribe to live metrics via Combine

```swift
import Combine
import PerformanceProfiler

var cancellables = Set<AnyCancellable>()

profiler.samplePublisher
    .receive(on: DispatchQueue.main)
    .sink { sample in
        print("CPU: \(sample.cpuUsage)  Memory: \(sample.memoryBytes)  FPS: \(sample.fps ?? 0)")
    }
    .store(in: &cancellables)
```

### 3. Add the floating SwiftUI overlay

```swift
import SwiftUI
import ProfilerUI
import PerformanceProfiler

struct ContentView: View {
    let profiler = PerformanceProfiler()

    var body: some View {
        YourMainView()
            .overlay(alignment: .topLeading) {
                ProfilerOverlayView(profiler: profiler)
                    .padding(12)
            }
            .task {
                await profiler.start()
            }
    }
}
```

The overlay shows a compact bar (CPU + FPS) by default. Tap the chevron to expand it into a full panel with sparkline graphs for all metrics. Drag it anywhere on screen.

### 4. Export a trace to JSON

```swift
import PerformanceProfiler

let trace = profiler.currentTrace()

do {
    let data = try TraceExporter.exportJSON(trace)
    // Write to disk, upload to a server, share via UIActivityViewController, etc.
    try data.write(to: URL.documentsDirectory.appending(path: "trace.json"))
} catch {
    print("Export failed: \(error)")
}
```

### 5. Using the overlay in a UIKit project

`ProfilerOverlayView` is a SwiftUI view, so host it with `UIHostingController` and add it as a child view controller pinned to the edges of your root view:

```swift
import UIKit
import SwiftUI
import ProfilerUI
import PerformanceProfiler

class ViewController: UIViewController {
    let profiler = PerformanceProfiler()

    override func viewDidLoad() {
        super.viewDidLoad()

        let overlay = ProfilerOverlayView(profiler: profiler)
        let hostingController = UIHostingController(rootView: overlay)
        hostingController.view.backgroundColor = .clear

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hostingController.didMove(toParent: self)

        Task { await profiler.start() }
    }
}
```

`PerformanceProfiler` and `TraceExporter` have no UIKit/SwiftUI dependency at all — you can use the Combine publisher or `currentTrace()` directly in any UIKit app without touching `ProfilerUI`.

### 6. App-wide overlay with one line (recommended for UIKit)

Hosting the overlay in a single view controller means it disappears whenever that screen isn't visible. `ProfilerOverlayWindow` handles all the `UIHostingController` / pass-through-window / touch-forwarding boilerplate internally — the client just calls `install(in:)` once:

```swift
import UIKit
import ProfilerUI

// SceneDelegate
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    // ... configure your main window as usual ...

    ProfilerOverlayWindow.install(in: windowScene)
}
```

That's it — no `UIHostingController`, no custom `UIWindow` subclass, no manual `profiler.start()` call required on your end. The overlay floats above every screen, modal, and even alerts, and survives navigation since it lives outside your view controller hierarchy entirely.

Need access to the underlying profiler (e.g. to export a trace)?

```swift
let overlay = ProfilerOverlayWindow.install(in: windowScene)
let trace = overlay.profiler.currentTrace()
```

To remove it: `ProfilerOverlayWindow.remove()`.

#### No `UIWindowScene`? (legacy single-window apps)

If your app doesn't use the scene-based lifecycle and just has a single `UIWindow` in `AppDelegate`, pass that window directly instead — same one-line API, no `UIWindowScene` required:

```swift
import UIKit
import ProfilerUI

func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    // ... configure self.window as usual ...

    ProfilerOverlayWindow.install(in: window!)
    return true
}
```

This attaches the overlay as a subview pinned to the window's edges instead of creating a second `UIWindow`, with the same touch-pass-through behavior — taps land on your app everywhere except directly on the overlay.

---

## Configuration

Pass a `ProfilerConfiguration` to customize behaviour:

```swift
let profiler = PerformanceProfiler(
    configuration: ProfilerConfiguration(
        samplingInterval: 0.1,       // seconds between samples (default 100 ms)
        ringBufferCapacity: 1024,    // max samples kept (must be a power of 2)
        trackFPS: true,              // enable CADisplayLink FPS tracking
        trackThermalState: true      // monitor device thermal state
    )
)
```

### Built-in presets

| Preset | Interval | FPS | Use case |
|---|---|---|---|
| `ProfilerConfiguration()` | 100 ms | ✅ | Development / debug overlay |
| `.lightweight` | 1 s | ❌ | Release-build background monitoring |
| `.highFrequency` | 33 ms (~30 Hz) | ✅ | Frame-drop debugging |

```swift
let profiler = PerformanceProfiler(configuration: .lightweight)
```

---

## Project Structure

```
Sources/
  ProfilerCore/          — Samplers, ring buffer, trace store (no UI dependencies)
    Samplers/            — CPUSampler, MemorySampler, FPSSampler, ThermalSampler
    Storage/             — RingBuffer, TraceStore
    Models/              — MetricSample, Trace
  PerformanceProfiler/   — Public API surface (PerformanceProfiler, ProfilerConfiguration, TraceExporter)
  ProfilerUI/            — SwiftUI overlay (ProfilerOverlayView, ProfilerViewModel, MetricGraphView)
Tests/
  ProfilerCoreTests/     — Unit tests for samplers, ring buffer, trace store
  PerformanceProfilerTests/ — Integration tests for trace export
```

---

## License

MIT. See [LICENSE](LICENSE) for details.
