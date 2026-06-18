# PerformanceProfiler

A lightweight Swift SDK for real-time CPU, memory, FPS, and thermal monitoring on iOS. Get live metrics via Combine publishers or a floating SwiftUI HUD — no Instruments required.

## Features

| | |
|---|---|
| 📊 **CPU · Memory · FPS · Thermal** | Sampled at a configurable interval |
| 📡 **Combine publisher** | Stream `MetricSample` values directly into your UI |
| 🪟 **Floating overlay** | Draggable HUD with mini sparkline graphs |
| 🏗️ **App-wide window** | One-call install that floats above every modal and alert |
| 📦 **JSON export** | Serialize a full trace to disk or send to a backend |
| 🔒 **Bounded memory** | Ring-buffer storage — oldest samples auto-discarded |

---

## Requirements

- iOS 16+
- Swift 5.9+
- Xcode 15+

---

## Installation

### Swift Package Manager

In Xcode: **File → Add Package Dependencies**, then enter:

```
https://github.com/rajatsha90271/PerformanceProfiler
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/rajatsha90271/PerformanceProfiler.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "PerformanceProfiler", package: "PerformanceProfiler"),
            .product(name: "ProfilerUI", package: "PerformanceProfiler"), // optional — SwiftUI overlay
        ]
    ),
]
```

Two products are available:

| Product | What it contains |
|---|---|
| `PerformanceProfiler` | Core SDK — samplers, Combine publisher, trace export. No UI dependency. |
| `ProfilerUI` | SwiftUI overlay views. Depends on `PerformanceProfiler`. |

---

## Usage

### Combine publisher

```swift
import Combine
import PerformanceProfiler

let profiler = PerformanceProfiler()
var cancellables = Set<AnyCancellable>()

// Subscribe before starting so you don't miss the first sample.
profiler.samplePublisher
    .receive(on: DispatchQueue.main)
    .sink { sample in
        print(String(format: "CPU %.1f%%  MEM %.1f MB  FPS %.0f  Thermal: %@",
                     sample.cpuUsage * 100,
                     sample.memoryMB,   // convenience var on MetricSample
                     sample.fps,
                     sample.thermalState.description))
    }
    .store(in: &cancellables)

// Start on the main actor.
Task { await profiler.start() }
```

### SwiftUI overlay

Drop `ProfilerOverlayView` anywhere in your view hierarchy. It positions itself via an offset and a drag gesture — no layout constraints needed.

```swift
import SwiftUI
import PerformanceProfiler
import ProfilerUI

struct ContentView: View {

    private let profiler = PerformanceProfiler()

    var body: some View {
        YourMainView()
            .overlay(alignment: .topLeading) {
                ProfilerOverlayView(profiler: profiler)
                    .padding(12)
            }
            .task { await profiler.start() }
    }
}
```

The HUD shows a compact bar (CPU + FPS) by default. Tap the **chevron** to expand it into a full panel with sparkline graphs for CPU, memory, and FPS. Drag it anywhere on screen.

### App-wide overlay — UIKit (recommended for UIKit apps)

`ProfilerOverlayWindow` creates its own `UIWindow` at `.alert + 1`, so the HUD floats above every screen, modal sheet, and system alert without any per-view-controller wiring.

```swift
// SceneDelegate.swift
import UIKit
import ProfilerUI

func scene(_ scene: UIScene,
           willConnectTo session: UISceneSession,
           options: UIScene.ConnectionOptions) {

    guard let windowScene = scene as? UIWindowScene else { return }
    // … set up your main window as usual …

    ProfilerOverlayWindow.install(in: windowScene)
}
```

Need access to the underlying profiler later (e.g. to export a trace)?

```swift
let overlay = ProfilerOverlayWindow.install(in: windowScene)
let data = try TraceExporter.exportJSON(overlay.profiler.currentTrace())
```

To tear it down: `ProfilerOverlayWindow.remove()`.

#### Legacy single-window apps (no `UIWindowScene`)

```swift
// AppDelegate.swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions ...) -> Bool {
    ProfilerOverlayWindow.install(in: window!)
    return true
}
```

This attaches the HUD as a pinned subview instead of a second window, with identical touch-pass-through behaviour.

### Trace export

```swift
import PerformanceProfiler

// Export a snapshot at any point — profiler keeps running.
let trace = profiler.currentTrace()

do {
    let data = try TraceExporter.exportJSON(trace)
    try data.write(to: URL.documentsDirectory.appending(path: "trace.json"))
} catch {
    print("Export failed:", error)
}

// Or stop the session and export the completed trace.
let finalTrace = await profiler.stop()
```

---

## Configuration

`ProfilerConfiguration` controls sampling rate, buffer size, and which subsystems are active. Pass it to the `PerformanceProfiler` initializer.

```swift
let profiler = PerformanceProfiler(
    configuration: ProfilerConfiguration(
        samplingInterval: 0.1,    // seconds between samples (default 100 ms)
        ringBufferCapacity: 1024, // max samples retained — must be a power of 2
        trackFPS: true,           // CADisplayLink FPS tracking
        trackThermalState: true   // device thermal state
    )
)
```

### Built-in presets

| Preset | Interval | FPS | Best for |
|---|---|---|---|
| `ProfilerConfiguration()` | 100 ms | ✅ | Debug overlay during development |
| `.lightweight` | 1 s | ❌ | Release-build background monitoring |
| `.highFrequency` | 33 ms | ✅ | Diagnosing frame drops |

```swift
let profiler = PerformanceProfiler(configuration: .highFrequency)
```

---

## MetricSample reference

```swift
public struct MetricSample {
    let timestamp: Double      // seconds since process launch (CACurrentMediaTime)
    let cpuUsage: Float        // fractional across all cores — can exceed 1.0 on multi-core
    let memoryBytes: UInt64    // physical footprint in bytes
    let fps: Float             // 0–120; 0 when FPS tracking is disabled
    let thermalState: ThermalState  // .nominal / .fair / .serious / .critical

    var memoryMB: Float { Float(memoryBytes) / 1_048_576 }
}
```

---

## Project structure

```
Sources/
  ProfilerCore/               No UI dependencies — safe in app extensions
    Samplers/                 CPUSampler  MemorySampler  FPSSampler  ThermalSampler
    Storage/                  RingBuffer  TraceStore
    Models/                   MetricSample  Trace
  PerformanceProfiler/        Public API — PerformanceProfiler  ProfilerConfiguration  TraceExporter
  ProfilerUI/                 SwiftUI layer — ProfilerOverlayView  ProfilerViewModel  MetricGraphView
                              UIKit layer — ProfilerOverlayWindow
Tests/
  ProfilerCoreTests/          Ring buffer, sampler, trace store unit tests
  PerformanceProfilerTests/   Trace export integration tests
TestApp/                      Xcode project — open to run a live demo on a device or simulator
```

---

## Example app

Open `TestApp/TestApp.xcodeproj` in Xcode. The project uses a local package reference to the SDK root, so changes you make to the library are immediately reflected. Run on any iOS 16 simulator or device — no additional setup needed.

The app has two tabs:

- **Overlay** — demonstrates `ProfilerOverlayWindow`, configuration presets, and trace JSON export
- **Raw Metrics** — live `MetricSample` stream via the Combine publisher, with a scrollable history table

---

## License

MIT. See [LICENSE](LICENSE) for details.
