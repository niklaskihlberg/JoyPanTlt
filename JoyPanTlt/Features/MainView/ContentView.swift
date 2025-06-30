//
//  ContentView.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//  Refactored by Niklas Kihlberg on 2025-06-29.
//

import SwiftUI
import Combine

struct ContentView: View {
    // MARK: - View Model (Dependency Injected)
    @StateObject var viewModel: ContentViewModel
    
    // MARK: - Environment
    @Environment(\.openWindow) private var openWindow
    
    // MARK: - Initialization
    init(viewModel: ContentViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            // Primary blurred transparent background
            VisualEffectBackground(
                material: .hudWindow,
                blendingMode: .behindWindow,
                emphasized: true
            )
            .ignoresSafeArea()
            
            // Subtle dark overlay for better contrast
            Color.black.opacity(0.15)
                .ignoresSafeArea()
            
            GeometryReader { geometry in
                joystickLayoutView(for: geometry)
            }
            
            // Hidden buttons för keyboard shortcuts
            VStack {
                Button("Settings") {
                    openWindow(id: "settings")
                }
                .keyboardShortcut(",", modifiers: .command)
                .hidden()
                
                Button("Help") {
                    openWindow(id: "help")
                }
                .keyboardShortcut("?", modifiers: .command)
                .hidden()
            }
        }
        .onAppear {
            viewModel.onViewAppear()
        }
        .onReceive(viewModel.virtualJoystickConfig.$numberOfJoysticks) { newCount in
            print("🔄 ContentView: Received numberOfJoysticks change to \(newCount)")
            viewModel.onNumberOfJoysticksChanged(newCount: newCount)
        }
    }
    
    // MARK: - Private Methods
    private func joystickLayoutView(for geometry: GeometryProxy) -> some View {
        ZStack {
            // Background dimming
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            // Osynlig focusable vy för tangentbordsinput
            Color.clear
                .contentShape(Rectangle())
                .focusable(true)
                .focusEffectDisabled()
                .onKeyPress(phases: .all) { keyPress in
                    print("🎹 ContentView: Key press detected: \(keyPress.key), phase: \(keyPress.phase)")
                    let result = viewModel.handleKeyPress(keyPress)
                    print("🎹 ContentView: Key press result: \(result)")
                    return result
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            GeometryReader { innerGeometry in
                let windowSize = innerGeometry.size
                let joystickSize = viewModel.calculateJoystickSize(for: windowSize)
                let columns = viewModel.calculateColumns(for: viewModel.numberOfJoysticks)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: columns), spacing: 15) {
                    ForEach(Array(viewModel.getEnabledJoysticks().enumerated()), id: \.element.id) { index, joystick in
                        JoystickGridItem(
                            joystick: joystick,
                            index: index,
                            size: joystickSize,
                            totalJoysticks: viewModel.numberOfJoysticks, // NY: Skicka med total antal
                            keyboardPosition: Binding(
                                get: { 
                                    index < viewModel.keyboardControlledPositions.count ? viewModel.keyboardControlledPositions[index] : CGPoint.zero
                                },
                                set: { newValue in
                                    if index < viewModel.keyboardControlledPositions.count {
                                        viewModel.keyboardControlledPositions[index] = newValue
                                    }
                                }
                            )
                        ) { position in
                            viewModel.updatePanTilt(from: position, joystickIndex: index)
                        }
                        .id("unified-joystick-\(index)")
                    }
                }
                .padding(15) // Mindre padding för att ge joysticken mer plats
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .if(viewModel.numberOfJoysticks == 1) { view in
                    view.position(x: windowSize.width / 2, y: windowSize.height / 2)
                }
            }
        }
    }
}

// Helper extension för conditional modifiers
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    let coordinator = AppCoordinator()
    ContentView(viewModel: coordinator.makeContentViewModel())
}
