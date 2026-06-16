//
//  ProfilerOverlayWindow.swift
//  PerformanceProfiler
//

#if canImport(UIKit)
import UIKit
import SwiftUI
import PerformanceProfiler

/// Hosts `ProfilerOverlayView` so it floats above every screen, modal, and alert
/// without any per-view-controller wiring.
///
/// Use `install(in:)` with a `UIWindowScene` if your app uses the scene-based
/// lifecycle, or `install(in:)` with your existing `UIWindow` if it doesn't
/// (e.g. a legacy `AppDelegate.window` single-window app).
///
/// ```swift
/// // SceneDelegate (scene-based apps)
/// func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
///     guard let windowScene = scene as? UIWindowScene else { return }
///     ProfilerOverlayWindow.install(in: windowScene)
/// }
///
/// // AppDelegate (no scene, single window)
/// func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) -> Bool {
///     ProfilerOverlayWindow.install(in: window!)
///     return true
/// }
/// ```
@MainActor
public final class ProfilerOverlayWindow {

    private static var current: ProfilerOverlayWindow?

    private let host: Host
    public let profiler: PerformanceProfiler

    /// Installs the floating overlay as its own top-level window in the given
    /// window scene, and starts the profiler.
    /// - Parameters:
    ///   - scene: The `UIWindowScene` to attach the overlay window to.
    ///   - configuration: Profiler sampling configuration. Defaults to `ProfilerConfiguration()`.
    /// - Returns: The installed instance, in case you want to call `remove()` later.
    @discardableResult
    public static func install(
        in scene: UIWindowScene,
        configuration: ProfilerConfiguration = ProfilerConfiguration()
    ) -> ProfilerOverlayWindow {
        let instance = ProfilerOverlayWindow(scene: scene, configuration: configuration)
        current = instance
        return instance
    }

    /// Installs the floating overlay directly on top of an existing `UIWindow`
    /// (for apps that don't use `UIWindowScene`, e.g. a single window created
    /// in `AppDelegate`), and starts the profiler.
    /// - Parameters:
    ///   - window: The app's existing window to overlay.
    ///   - configuration: Profiler sampling configuration. Defaults to `ProfilerConfiguration()`.
    /// - Returns: The installed instance, in case you want to call `remove()` later.
    @discardableResult
    public static func install(
        in window: UIWindow,
        configuration: ProfilerConfiguration = ProfilerConfiguration()
    ) -> ProfilerOverlayWindow {
        let instance = ProfilerOverlayWindow(attachingTo: window, configuration: configuration)
        current = instance
        return instance
    }

    /// Removes the overlay and stops the profiler.
    public static func remove() {
        current?.host.tearDown()
        current = nil
    }

    private init(scene: UIWindowScene, configuration: ProfilerConfiguration) {
        let profiler = PerformanceProfiler(configuration: configuration)
        self.profiler = profiler

        let hostingController = UIHostingController(
            rootView: ProfilerOverlayView(profiler: profiler).padding(12)
        )
        hostingController.view.backgroundColor = .clear

        let window = PassthroughWindow(windowScene: scene)
        window.rootViewController = hostingController
        window.windowLevel = .alert + 1
        window.isHidden = false
        self.host = .ownWindow(window)

        Task { await profiler.start() }
    }

    private init(attachingTo parentWindow: UIWindow, configuration: ProfilerConfiguration) {
        let profiler = PerformanceProfiler(configuration: configuration)
        self.profiler = profiler

        let hostingController = UIHostingController(
            rootView: ProfilerOverlayView(profiler: profiler).padding(12)
        )
        hostingController.view.backgroundColor = .clear

        let containerView = PassthroughView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        parentWindow.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: parentWindow.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: parentWindow.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: parentWindow.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: parentWindow.trailingAnchor),
        ])
        parentWindow.bringSubviewToFront(containerView)
        self.host = .attachedView(containerView, contentView: hostingController.view)

        Task { await profiler.start() }
    }

    /// Where the overlay's view hierarchy lives, so `remove()` can tear it down either way.
    private enum Host {
        case ownWindow(UIWindow)
        case attachedView(UIView, contentView: UIView)

        func tearDown() {
            switch self {
            case .ownWindow(let window):
                window.isHidden = true
            case .attachedView(let container, _):
                container.removeFromSuperview()
            }
        }
    }
}

/// A window that only accepts touches inside its rootViewController's content,
/// letting everything else fall through to the app's main window underneath.
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event) else { return nil }
        return hitView == rootViewController?.view ? nil : hitView
    }
}

/// A transparent full-bounds view that only accepts touches that land on one of
/// its visible subviews (the overlay itself), letting everything else fall
/// through to the views beneath it in the same window.
private final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event) else { return nil }
        return hitView == self ? nil : hitView
    }
}
#endif
