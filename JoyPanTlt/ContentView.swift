//
//  ContentView.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//  Refactored by Niklas Kihlberg on 2025-06-29.

import SwiftUI
import Combine

struct VisualEffectBlur: NSViewRepresentable {

  var material: NSVisualEffectView.Material
  var blendingMode: NSVisualEffectView.BlendingMode
  var emphasized: Bool = false
  
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = blendingMode
    view.state = .active
    view.isEmphasized = emphasized
    return view
  }
  
  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    nsView.material = material
    nsView.blendingMode = blendingMode
    nsView.isEmphasized = emphasized
  }
}

struct ContentView: View {
  
  @EnvironmentObject var virtualjoysticks: VIRTUALJOYSTICKS
  @EnvironmentObject var osc: OSC
  @EnvironmentObject var midi: MIDI
  @EnvironmentObject var gamepad: GAMEPAD
  
  var body: some View {

    ZStack {
      VisualEffectBlur(
        material: .hudWindow,
        blendingMode: .behindWindow,
        emphasized: true
      )
      .ignoresSafeArea()
      
      Color.black.opacity(0.125)
        .ignoresSafeArea()
      
      GeometryReader { geometry in
        JoystickLayout(for: geometry)
      }
    }
    .onAppear {
      NSApp.activate(ignoringOtherApps: true)   
    }
  }
  
  // MARK: - Private Methods
  private func JoystickLayout(for geometry: GeometryProxy) -> some View {
    ZStack {
      GeometryReader { innerGeometry in
        
        let columns = calculateColumns(for: virtualjoysticks.numberOfJoysticks)
        
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: 32), count: columns),
          spacing: 32
        ) {
          
          ForEach(Array(virtualjoysticks.joystickInstances.enumerated()), id: \.element.id) { index, joystick in
            
            
            JoystickWidget(index: index, joystick: joystick) { position in

              let deadzone = joystick.deadzone
              if sqrt(position.x * position.x + position.y * position.y) < deadzone {
                return
              }

              let value = TranslationLogic.convertJoystickToPanTilt(position, for: joystick)

              joystick.pan = value.pan
              joystick.tilt = value.tilt

              osc.sendPanTilt(
                panAddress: joystick.oscPanAddress,
                panValue: value.pan,
                tiltAddress: joystick.oscTiltAddress,
                tiltValue: value.tilt
              )
              midi.sendControlChange(
                channel: Int(joystick.midiCHX),
                controller: Int(joystick.midiCCX),
                value: Int(value.pan)
              )
              midi.sendControlChange(
                channel: Int(joystick.midiCHY),
                controller: Int(joystick.midiCCY),
                value: Int(value.tilt)
              )
            }
          }
          .id("unified-joystick-\(JoystickLayout(for: innerGeometry))")
        }
      }
      .padding(32)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

// MARK: - Layout Helpers (Public)
func calculateColumns(for joystickCount: Int) -> Int {
  switch joystickCount {
     case 1: return 1
     case 2: return 2
     case 3: return 3
     case 4...9: return 4
  default: return 4
  }
}

// #Preview {
//   ContentView()
//     .environmentObject(VIRTUALJOYSTICKS())
//     .environmentObject(OSC())
//     .environmentObject(MIDI())
//     .environmentObject(GAMEPAD())
// }
