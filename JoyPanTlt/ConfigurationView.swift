//
//  ConfigurationView.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import SwiftUI

struct ConfigurationView: View {
  @StateObject private var oscManager = OSCManager.shared
  @StateObject private var gamepadManager = GamepadManager.shared
  @StateObject private var virtualJoystickManager = VirtualJoystickManager.shared
  
  @State private var selectedTab: SettingsTab = .virtualJoystick
  
  enum SettingsTab: String, CaseIterable {
    case virtualJoystick = "Virtual Joystick"
    case osc = "OSC"
    case midi = "MIDI"  // <- Lägg till denna
    case gamepad = "Gamepad"
    
    var icon: String {
      switch self {
      case .virtualJoystick:
        return "dot.circle.and.hand.point.up.left.fill"
      case .osc:
        return "network"
      case .midi:  // <- Lägg till denna
        return "pianokeys"
      case .gamepad:
        return "gamecontroller"
      }
    }
  }
  
  var body: some View {
    NavigationView {
      
      // Sidebar med inställningskategorier
      List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
        Label(tab.rawValue, systemImage: tab.icon)
          .tag(tab)
          .padding(.vertical, 4)  // FIX: Lägg till vertikal padding
          .padding(.horizontal, 8)  // FIX: Lägg till horisontell padding
      }
      .listStyle(SidebarListStyle())
      .frame(minWidth: 180)  // FIX: Öka minWidth för att ge mer utrymme
      
      // Main content area - delegera till respektive konfiguration
      Group {
        switch selectedTab {
        case .virtualJoystick:
          VirtualJoystickSettingsView()
        case .osc:
          OSCSettingsView()
        case .midi:  // <- Lägg till denna
          MIDISettingsView()
        case .gamepad:
          GamepadSettingsView()
        }
      }
      .frame(minWidth: 400, minHeight: 300)
    }
    .navigationTitle("Settings")
  }
}


#Preview {
  ConfigurationView()
    .frame(width: 600, height: 400)
}

