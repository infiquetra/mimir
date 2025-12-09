import Cocoa
import FlutterMacOS

class WindowResizePlugin: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.infiquetra.mimir/window_resize",
            binaryMessenger: registrar.messenger)
        let instance = WindowResizePlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setSize":
            guard let args = call.arguments as? [String: Any],
                  let width = args["width"] as? Double,
                  let height = args["height"] as? Double else {
                result(FlutterError(code: "INVALID_ARGS", message: "width and height required", details: nil))
                return
            }

            if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
                let frame = NSRect(x: window.frame.origin.x, y: window.frame.origin.y, width: width, height: height)
                window.setFrame(frame, display: true, animate: false)
                window.center()
                result(nil)
            } else {
                result(FlutterError(code: "NO_WINDOW", message: "No window found", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
