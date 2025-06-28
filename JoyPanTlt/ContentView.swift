//
//  ContentView.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import SwiftUI

struct ContentView: View {
  @State private var panTiltValues: [(pan: Double, tilt: Double)] = [(0.0, 0.0)]
  
  // Shared managers
  @StateObject private var oscManager = OSCManager.shared
  @StateObject private var virtualJoystickManager = VirtualJoystickManager.shared
  @StateObject private var midiManager = MIDIManager.shared
  
  @Environment(\.openWindow) private var openWindow
  
  var body: some View {
    ZStack {
      // Blurred transparent background
      VisualEffectBackground()
        .ignoresSafeArea()
      
      // Dark gray overlay
      Color.black.opacity(0.3)
        .ignoresSafeArea()
      
      GeometryReader { geometry in
        if virtualJoystickManager.configuration.numberOfJoysticks == 1 {
          // Single joystick - centrerad i mitten
          VStack {
            Spacer()
            HStack {
              Spacer()
              VirtualJoystick(
                onPositionChanged: { position in
                  updatePanTilt(from: position, joystickIndex: 0)
                },
                onInputMethodChanged: { method in
                  print("🎮 Input method changed to: \(method)")
                }
              )
              .frame(width: singleJoystickSize, height: singleJoystickSize)
              Spacer()
            }
            Spacer()
          }
        } else {
          // Multiple joysticks - smart grid layout
          VStack {
            Spacer()
            LazyVGrid(columns: smartGridColumns(for: geometry), spacing: gridSpacing) {
              ForEach(Array(virtualJoystickManager.configuration.getEnabledJoysticks().enumerated()), id: \.element.id) { index, joystick in
                JoystickGridItem(joystick: joystick, index: index, size: multiJoystickSize(for: geometry)) { position in
                  updatePanTilt(from: position, joystickIndex: index)
                }
              }
            }
            Spacer()
          }
          .padding(20)
        }
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
    .onChange(of: virtualJoystickManager.configuration.sensitivityValue) {
      TranslationLogic.setSensitivity(virtualJoystickManager.configuration.sensitivityValue)
    }
    .onAppear {
      TranslationLogic.setSensitivity(virtualJoystickManager.configuration.sensitivityValue)
      initializePanTiltValues()
    }
    .onChange(of: virtualJoystickManager.configuration.numberOfJoysticks) {
      initializePanTiltValues()
    }
  }
  
  // MARK: - Computed Properties
  private var gridColumns: [GridItem] {
    let enabledCount = virtualJoystickManager.configuration.getEnabledJoysticks().count
    let columns = min(enabledCount, enabledCount <= 4 ? 2 : 3)
    return Array(repeating: GridItem(.flexible()), count: columns)
  }
  
  private var joystickSize: CGFloat {
    let enabledCount = virtualJoystickManager.configuration.getEnabledJoysticks().count
    return enabledCount <= 4 ? 180 : 140
  }
  
  // MARK: - Smart Layout Computed Properties
  
  private func smartGridColumns(for geometry: GeometryProxy) -> [GridItem] {
    let enabledCount = virtualJoystickManager.configuration.getEnabledJoysticks().count
    let screenWidth = geometry.size.width
    let screenHeight = geometry.size.height
    let aspectRatio = screenWidth / screenHeight
    
    // Bestäm antal kolumner baserat på antal joysticks och skärmproportioner
    let columns: Int
    
    switch enabledCount {
    case 1:
      columns = 1
    case 2:
      // 2 joysticks: 1x2 (vertikal) om högt fönster, 2x1 (horisontell) om brett
      columns = aspectRatio > 1.2 ? 2 : 1
    case 3:
      // 3 joysticks: försök få en bra layout
      columns = aspectRatio > 1.5 ? 3 : 2
    case 4:
      // 4 joysticks: 2x2 grid är perfekt
      columns = 2
    case 5...6:
      // 5-6 joysticks: 3x2 eller 2x3 beroende på proportioner
      columns = aspectRatio > 1.3 ? 3 : 2
    case 7...8:
      // 7-8 joysticks: försök få 3 eller 4 kolumner
      columns = aspectRatio > 1.8 ? 4 : 3
    default:
      columns = min(enabledCount, 4)
    }
    
    return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: columns)
  }
  
  private var gridSpacing: CGFloat {
    let enabledCount = virtualJoystickManager.configuration.getEnabledJoysticks().count
    return enabledCount <= 4 ? 30 : 20
  }
  
  private var singleJoystickSize: CGFloat {
    // Större joystick när det bara är en
    return 250
  }
  
  private func multiJoystickSize(for geometry: GeometryProxy) -> CGFloat {
    let enabledCount = virtualJoystickManager.configuration.getEnabledJoysticks().count
    let availableWidth = geometry.size.width - 40 // Padding
    let availableHeight = geometry.size.height - 100 // Padding + toolbar space
    
    // Beräkna kolumner och rader
    let columns = smartGridColumns(for: geometry).count
    let rows = Int(ceil(Double(enabledCount) / Double(columns)))
    
    // Beräkna maximal storlek baserat på tillgängligt utrymme
    let maxWidthPerJoystick = (availableWidth - CGFloat(columns - 1) * gridSpacing) / CGFloat(columns)
    let maxHeightPerJoystick = (availableHeight - CGFloat(rows - 1) * gridSpacing - CGFloat(rows * 40)) / CGFloat(rows) // 40 för text + status
    
    let calculatedSize = min(maxWidthPerJoystick, maxHeightPerJoystick)
    
    // Sätt min/max gränser
    return max(100, min(200, calculatedSize))
  }
  
  // MARK: - Functions
  private func initializePanTiltValues() {
    let count = virtualJoystickManager.configuration.numberOfJoysticks
    panTiltValues = Array(repeating: (0.0, 0.0), count: count)
  }
  
  private func updatePanTilt(from position: CGPoint, joystickIndex: Int) {
    let result = TranslationLogic.convertJoystickToPanTilt(position)
    
    // Update local values
    if joystickIndex < panTiltValues.count {
      panTiltValues[joystickIndex] = (result.pan, result.tilt)
    }
    
    if virtualJoystickManager.configuration.numberOfJoysticks == 1 {
      // Single joystick - använd single joystick adresser
      oscManager.updatePanTiltWithAddresses(
        pan: result.pan,
        tilt: result.tilt,
        panAddress: virtualJoystickManager.configuration.singleJoystickPanAddress,
        tiltAddress: virtualJoystickManager.configuration.singleJoystickTiltAddress
      )
      
      print("🕹️ Single: Pan=\(String(format: "%.1f", result.pan))° → \(virtualJoystickManager.configuration.singleJoystickPanAddress)")
      
    } else {
      // Multiple joysticks - använd joystick-specifika adresser
      let enabledJoysticks = virtualJoystickManager.configuration.getEnabledJoysticks()
      guard joystickIndex < enabledJoysticks.count else { return }
      
      let joystick = enabledJoysticks[joystickIndex]
      
      oscManager.updatePanTiltWithAddresses(
        pan: result.pan,
        tilt: result.tilt,
        panAddress: joystick.oscPanAddress,
        tiltAddress: joystick.oscTiltAddress
      )
      
      print("🕹️ \(joystick.name): Pan=\(String(format: "%.1f", result.pan))° → \(joystick.oscPanAddress)")
      print("🕹️ \(joystick.name): Tilt=\(String(format: "%.1f", result.tilt))° → \(joystick.oscTiltAddress)")
    }
    
    // MIDI (använd befintlig logik)
    midiManager.updatePanTilt(pan: result.pan, tilt: result.tilt)
  }
}

struct JoystickGridItem: View {
  let joystick: JoystickInstance
  let index: Int
  let size: CGFloat
  let onPositionChanged: (CGPoint) -> Void
  
  var body: some View {
    VStack(spacing: 8) {
      Text(joystick.name)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(.white)
        .lineLimit(1)
      
      VirtualJoystick(
        onPositionChanged: onPositionChanged,
        onInputMethodChanged: { method in
          print("🎮 \(joystick.name) input method: \(method)")
        }
      )
      .frame(width: size, height: size)
      .background(Color.black.opacity(0.6))
      .cornerRadius(8)
      
      // Status indicator
      HStack(spacing: 4) {
        Circle()
          .fill(joystick.isEnabled ? Color.green : Color.gray)
          .frame(width: 6, height: 6)
        Text("Ch \(joystick.midiChannel)")
          .font(.caption2)
          .foregroundColor(.gray)
      }
      .padding(6)
      .background(Color.black.opacity(0.8))
      .cornerRadius(4)
    }
  }
}

struct VisualEffectBackground: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let effectView = NSVisualEffectView()
    effectView.material = .hudWindow
    effectView.blendingMode = .behindWindow
    effectView.state = .active
    return effectView
  }
  
  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    // No updates needed
  }
}

#Preview {
  ContentView()
}
