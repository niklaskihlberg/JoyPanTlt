//
//  ConfigurationView.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import SwiftUI

struct SettingsView: View {
  @State private var selectedTab: SettingsTab

  init(selectedTab: SettingsTab = .virtualjoysticks) {
      _selectedTab = State(initialValue: selectedTab)
  }
  
  @EnvironmentObject var virtualjoysticks: VIRTUALJOYSTICKS
  @EnvironmentObject var osc: OSC
  @EnvironmentObject var midi: MIDI
  @EnvironmentObject var gamepad: GAMEPAD
  
  enum SettingsTab: String, CaseIterable {
    case virtualjoysticks = "Virtual Joysticks"
    case osc = "OSC"
    case midi = "MIDI"
    case gamepad = "Gamepad"
    case fixture = "Fixture"
    case visualization = "Visualization"
    
    var icon: String {
      switch self {
      case .virtualjoysticks: return "dot.circle.and.hand.point.up.left.fill"
      case .osc: return "network"
      case .midi: return "pianokeys"
      case .gamepad: return "gamecontroller.fill"
      case .fixture: return "slider.horizontal.3"
      case .visualization: return "photo.on.rectangle.angled"
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
        case .virtualjoysticks: VirtualJoysticksSettingsView()
        case .osc: OSCSettingsView()
        case .midi: MIDISettingsView()
        case .gamepad: GamepadSettingsView()
        case .fixture: FixtureSettingsView()
        case .visualization: VisualizationView()
        }
      }
      .frame(minWidth: 360, minHeight: 340)
    }
    .navigationTitle("Settings")
    .frame(minWidth: 720, maxWidth: 720)
  }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    class DummyOSC: ObservableObject {}
    class DummyMIDI: ObservableObject {}
    // class DummyGamepad: GAMEPAD {}

    static var previews: some View {
        SettingsView(selectedTab: .gamepad)
            .environmentObject(VIRTUALJOYSTICKS()) // Använd riktiga klassen här
            .environmentObject(DummyOSC())
            .environmentObject(DummyMIDI())
            .environmentObject(GAMEPAD())
            .frame(width: 720, height: 400)
    }
}
#endif
