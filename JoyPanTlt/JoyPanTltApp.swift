//
//  App.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import SwiftUI

@main
struct JoyPanTltApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("JoyPanTlt Help") {
                    // Öppna hjälp-fönster
                    if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "help" }) {
                        window.makeKeyAndOrderFront(nil)
                    } else {
                        // Använd NotificationCenter för att be ContentView öppna hjälp
                        NotificationCenter.default.post(name: NSNotification.Name("OpenHelp"), object: nil)
                    }
                }
                .keyboardShortcut("?")
            }
        }
        
        // Settings Window
        WindowGroup("Settings", id: "settings") {
            ConfigurationView()
        }
        .windowResizability(.contentSize)
        
        // Help Window
        WindowGroup("Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)
    }
}