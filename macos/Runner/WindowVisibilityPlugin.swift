import Cocoa
import FlutterMacOS

/// Per-engine window visibility bridge.
///
/// Bound to the registrar's actual NSWindow (not the main window by
/// assumption) so each Flutter engine observes its own hide/show/close
/// and application-resume notifications.
class WindowVisibilityPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let registrar: FlutterPluginRegistrar
    private var eventSink: FlutterEventSink?
    private var observedWindow: NSWindow?
    private var observers: [NSObjectProtocol] = []
    private var bindAttempts = 0

    init(with registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        print("WindowVisibilityPlugin: Registered with registrar")
        let methodChannel = FlutterMethodChannel(
            name: "com.infiquetra.mimir/window_visibility",
            binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(
            name: "com.infiquetra.mimir/window_visibility_events",
            binaryMessenger: registrar.messenger)
        let instance = WindowVisibilityPlugin(with: registrar)
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "attach":
            bindWindow()
            result(nil)
        case "detach":
            detachObservers()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        bindWindow()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        detachObservers()
        eventSink = nil
        return nil
    }

    private func bindWindow() {
        if let window = registrar.view?.window {
            attachObservers(to: window)
            return
        }
        guard bindAttempts < 20 else {
            print("WindowVisibilityPlugin: No window found for this registrar")
            return
        }
        bindAttempts += 1
        DispatchQueue.main.async { [weak self] in
            self?.bindWindow()
        }
    }

    private func attachObservers(to window: NSWindow) {
        detachObservers()
        observedWindow = window
        let center = NotificationCenter.default

        observers.append(center.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.emit("visible")
        })
        observers.append(center.addObserver(
            forName: NSWindow.didDeminiaturizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.emit("visible")
        })
        observers.append(center.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow else { return }
            if window.occlusionState.contains(.visible) && !window.isMiniaturized {
                self?.emit("visible")
            } else {
                self?.emit("hidden")
            }
        })
        observers.append(center.addObserver(
            forName: NSWindow.didMiniaturizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.emit("hidden")
        })
        observers.append(center.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            if window.isMiniaturized || !window.isVisible {
                self?.emit("hidden")
            }
        })
        observers.append(center.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.emit("closed")
        })
        observers.append(center.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApplication.shared,
            queue: .main
        ) { [weak self] _ in
            self?.emit("resume")
        })
        observers.append(center.addObserver(
            forName: NSApplication.didHideNotification,
            object: NSApplication.shared,
            queue: .main
        ) { [weak self] _ in
            self?.emit("hidden")
        })
        observers.append(center.addObserver(
            forName: NSApplication.didUnhideNotification,
            object: NSApplication.shared,
            queue: .main
        ) { [weak self] _ in
            self?.emit("visible")
        })
        print("WindowVisibilityPlugin: Observers attached to engine window")
    }

    private func detachObservers() {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        observedWindow = nil
        bindAttempts = 0
    }

    private func emit(_ state: String) {
        eventSink?(["state": state])
    }
}
