import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register custom window resize plugin for the MAIN window
    WindowResizePlugin.register(with: flutterViewController.registrar(forPlugin: "WindowResizePlugin"))

    // Set callback to register WindowResizePlugin for ALL sub-windows
    // This must be done BEFORE any sub-windows are created
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { subWindowController in
      NSLog("WindowResizePlugin: Callback invoked for sub-window")
      WindowResizePlugin.register(
        with: subWindowController.registrar(forPlugin: "WindowResizePlugin")
      )
      NSLog("WindowResizePlugin: Sub-window registration complete")
    }
    NSLog("WindowResizePlugin: Callback registered in MainFlutterWindow")

    super.awakeFromNib()
  }
}
