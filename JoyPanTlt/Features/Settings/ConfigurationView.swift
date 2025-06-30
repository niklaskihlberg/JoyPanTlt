//
//  ConfigurationView.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import SwiftUI

struct ConfigurationView: View {
    // MARK: - View Model (Dependency Injected)
    @StateObject var viewModel: ConfigurationViewModel
    
    // MARK: - Initialization
    init(viewModel: ConfigurationViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }    
    var body: some View {
        NavigationView {
            
            // Sidebar med inställningskategorier
            List(ConfigurationViewModel.SettingsTab.allCases, id: \.self, selection: $viewModel.selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
                    .padding(.vertical, 4)  // FIX: Lägg till vertikal padding
                    .padding(.horizontal, 8)  // FIX: Lägg till horisontell padding
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 180)  // FIX: Öka minWidth för att ge mer utrymme
            
            // Main content area - delegera till respektive konfiguration
            Group {
                switch viewModel.selectedTab {
                case .virtualJoystick:
                    VirtualJoystickSettingsView(virtualJoystickConfig: viewModel.virtualJoystickConfig)
                case .osc:
                    OSCSettingsView(virtualJoystickConfig: viewModel.virtualJoystickConfig)
                case .midi:
                    MIDISettingsView()
                case .gamepad:
                    GamepadSettingsView()
                case .keyCommand:
                    KeyCommandSettingsView()
                }
            }
            .frame(minWidth: 400, minHeight: 300)
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    let coordinator = AppCoordinator()
    return ConfigurationView(viewModel: coordinator.makeConfigurationViewModel())
        .frame(width: 600, height: 400)
}

