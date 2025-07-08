//
//  ConfigurationView.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import SwiftUI

struct SettingsView: View {
  @State private var selectedTab: SettingsTab = .virtualJoystick
  
  @EnvironmentObject var virtualjoysticks: VIRTUALJOYSTICKS
  @EnvironmentObject var osc: OSC
  @EnvironmentObject var midi: MIDI
  
  enum SettingsTab: String, CaseIterable {
    case virtualJoystick = "Virtual Joystick"
    case osc = "OSC"
    case midi = "MIDI"
    
    var icon: String {
      switch self {
      case .virtualJoystick: return "dot.circle.and.hand.point.up.left.fill"
      case .osc: return "network"
      case .midi: return "pianokeys"
      }
    }
  }
  
  var body: some View {
    
    NavigationView {
      List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
        Label(tab.rawValue, systemImage: tab.icon)
          .tag(tab)
          .padding(.vertical, 4)
          .padding(.horizontal, 8)
      }
      .listStyle(SidebarListStyle())
      .frame(minWidth: 180, maxWidth: 180)
      
      Group {
        switch selectedTab {
        case .virtualJoystick: VirtualJoystickSettingsView()
        case .osc: OSCSettingsView()
        case .midi: MIDISettingsView()
        }
      }
      .frame(minWidth: 360, minHeight: 340)
    }
    .navigationTitle("Settings")
    .frame(minWidth: 720, maxWidth: 720)
  }
}
