import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            NotificationCenter.default.post(name: NSNotification.Name("KeyDown"), object: nil, userInfo: ["keyCode": event.keyCode])
            return event
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            NotificationCenter.default.post(name: NSNotification.Name("KeyUp"), object: nil, userInfo: ["keyCode": event.keyCode])
            return event
        }
    }
}

@main
struct JoyPanTltApp: App {

  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  @StateObject private var virtualjoysticks = VIRTUALJOYSTICKS()  // Create and own the virtual joysticks
  @StateObject private var osc = OSC()  // Create and own the OSC backend)
  @StateObject private var midi = MIDI()  // Create and own the MIDI backend
  
  var body: some Scene {
    
    WindowGroup {
      ContentView()
        .environmentObject(virtualjoysticks)  // Inject the virtual joysticks into the environment
        .environmentObject(osc)  // Inject the OSC backend into the environment
        .environmentObject(midi)  // Inject the MIDI backend into the environment
        .onAppear {
          // Försök hitta huvudfönstret och sätt storlek
          if let window = NSApplication.shared.windows.first {
            window.setContentSize(NSSize(width: 256, height: 256))
            window.center()
          }
        }
        .onReceive(virtualjoysticks.$numberOfJoysticks) { count in
          if let window = NSApplication.shared.windows.first {
            window.setContentSize(windowSize(for: count))
          }
        }
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)
    
    Settings {
      SettingsView()
        .environmentObject(virtualjoysticks)
        .environmentObject(osc)
        .environmentObject(midi)
    }
  }
}

private func windowSize(for joystickCount: Int) -> NSSize {
    switch joystickCount {
    case 1:
        return NSSize(width: 256, height: 256)
    case 2:
        return NSSize(width: 2 * 256, height: 256)
    case 3:
        return NSSize(width: 3 * 256, height: 256)
    case 4:
        return NSSize(width: 4 * 256, height: 256)
    case 5...8:
        return NSSize(width: 4 * 256, height: 2 * 256)
    default:
        return NSSize(width: 256, height: 256)
    }
}
