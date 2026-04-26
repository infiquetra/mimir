import Cocoa
import FlutterMacOS
import desktop_multi_window

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    print("AppDelegate: applicationDidFinishLaunching called")

    // Register WindowResizePlugin for ALL sub-windows.
    // This callback is invoked by desktop_multi_window whenever a new window is created.
    // Without this, the WindowResizePlugin is only available in the main window,
    // causing resize calls in sub-windows to fail silently.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { flutterViewController in
      print("WindowResizePlugin: *** Callback invoked for sub-window ***")
      WindowResizePlugin.register(
        with: flutterViewController.registrar(forPlugin: "WindowResizePlugin")
      )
      print("WindowResizePlugin: *** Sub-window registration complete ***")
    }

    print("AppDelegate: Window creation callback set")
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // Keep app running in menu bar when all windows are closed
    // Users can reopen windows from the tray icon or quit via tray menu
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
