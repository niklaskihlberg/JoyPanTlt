//
//  VirtualJoystickConfiguration.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import Foundation
import SwiftUI
import Combine

class VIRTUALJOYSTICKS: ObservableObject {
  @Published var numberOfJoysticks: Int = 0 {
    didSet { updateJoystickInstances() }
  }
  @Published var joystickInstances: [JOY] = []
  
  init() { updateJoystickInstances() }
  
  func resetToDefaults() {
    numberOfJoysticks = 1
    joystickInstances = []
    updateJoystickInstances()
  }
  
  private func updateJoystickInstances() {
    if numberOfJoysticks < 1 { numberOfJoysticks = 1 }
    let currentCount = joystickInstances.count
    if numberOfJoysticks > currentCount {
      joystickInstances.append(JOY(numberOfJoysticks: numberOfJoysticks))
    } else if numberOfJoysticks < currentCount {
      joystickInstances = Array(joystickInstances.prefix(numberOfJoysticks))
    }
  }
  
  func updateJoystick(_ joystick: JOY) {
    if let index = joystickInstances.firstIndex(where: { $0.id == joystick.id }) {
      joystickInstances[index] = joystick
    }
  }
  
  class JOY: ObservableObject, Identifiable {
    
    @Published var id = UUID()
    @Published var name: String
    @Published var number: String
    init(numberOfJoysticks: Int) {
      self.name = "Joystick \(numberOfJoysticks)"
      self.number = "\(numberOfJoysticks)"
    }
    
    @Published var sensitivity: Double = 0.005
    @Published var invertX: Bool = false
    @Published var invertY: Bool = false
    @Published var deadzone: Double = 0.1
    @Published var damping: Double = 0.8

    @Published var minPan: Double = -270
    @Published var maxPan: Double = 270
    @Published var minTilt: Double = 0
    @Published var maxTilt: Double = 90
    @Published var allowFoldover: Bool = true
    @Published var invertAtFoldover: Bool = true
    
    @Published var X: Double = 0.0 // Aktuell joystick position X
    @Published var Y: Double = 0.0 // Aktuell joystick position Y
    
    @Published var oscEnabled: Bool = false
    @Published var oscPanAddress: String = "/fixture/selected/overrides/panAngle"
    @Published var oscTiltAddress: String = "/fixture/selected/overrides/tiltAngle"
    @Published var panOffsetEnabled: Bool = false
    @Published var tiltOffsetEnabled: Bool = false
    @Published var panOffset: Double = 0.0
    @Published var tiltOffset: Double = 0.0
    
    @Published var midiEnabled: Bool = false
    @Published var midiCHX: Int = 1
    @Published var midiCCX: Int = 1
    @Published var midiCHY: Int = 1
    @Published var midiCCY: Int = 2

    @Published var pan: Double = 0.0 // Aktuellt pan-värde
    @Published var tilt: Double = 0.0 // Aktuellt tilt-värde

    @Published var accumulatedPan: Double = 0.0 // Behövs om du vill kunna snurra flera varv och hantera flip korrekt.
    var deltaPan: Double = 0.0 // Behövs för att räkna ut delta mellan nuvarande och förra pan-värdet (för att veta när du passerar gränser).

    @Published var flip: Bool = false
    @Published var allowFlip: Bool = true

    @Published var lastPan: Double = 0 // Behövs för att veta om du passerat en gräns (för att toggla flip).

    @Published var rotationOffset: Double = 0 // Rotation offset i grader, används för att justera pan-värdet

    @Published var inputMappings: [GamepadInput: JoystickAction] = [:]

    



    
    func resetPosition(osc: OSC, midi: MIDI) {
      self.X = 0.0
      self.Y = 0.0
      self.accumulatedPan = 0.0
      self.deltaPan = 0.0
      self.lastPan = 0.0
      self.pan = 0.0
      self.tilt = 0.0
      self.flip = false
      osc.sendPanTilt(
        panAddress: self.oscPanAddress,
        panValue: 0,
        tiltAddress: self.oscTiltAddress,
        tiltValue: 0
      )
      midi.sendControlChange(
        channel: Int(self.midiCHX),
        controller: Int(self.midiCCX),
        value: Int(0)
      )
      midi.sendControlChange(
        channel: Int(self.midiCHY),
        controller: Int(self.midiCCY),
        value: Int(0)
      )
    }
  }
}

struct JoystickWidget: View {

  @EnvironmentObject var virtualjoysticks: VIRTUALJOYSTICKS
  @EnvironmentObject var osc: OSC
  @EnvironmentObject var midi: MIDI
  @EnvironmentObject var gamepad: GAMEPAD

  @State private var pressedKeys = Set<UInt16>()

  

  let index: Int

  @ObservedObject var joystick: VIRTUALJOYSTICKS.JOY

  let onPositionChanged: (CGPoint) -> Void
  
  @State private var position: CGPoint = .zero
  @State private var isDragging: Bool = false
  @State private var ValueUpdateTimer: Timer?
  
  static let washerSize: Double = 145
  static let knobSize: Double = 90
  let snapBackSpeed: Double = 0.25
  
  private var knobColor: Color { Color.gray }
  private var updateInterval: TimeInterval = 0.05
  private var radius: CGFloat { JoystickWidget.washerSize / 2 }
  private var knobRadius: CGFloat { JoystickWidget.knobSize / 2 }
  private var maxDistance: CGFloat { radius - knobRadius }
  
  init(
    index: Int,
    joystick: VIRTUALJOYSTICKS.JOY,
    onPositionChanged: @escaping (CGPoint) -> Void = { _ in }
  ) {
    self.index = index
    self.joystick = joystick
    self.onPositionChanged = onPositionChanged
  }
  
  var body: some View {
    VStack(spacing: 16) {
      ZStack {

      Circle() // Washer
        .fill(Color.white.opacity(0.0625))
        .stroke(Color.gray.opacity(0.03125), lineWidth: 5)
        .frame(width: JoystickWidget.washerSize, height: JoystickWidget.washerSize)
      
      Circle() // Knob (cut-out)
          .frame(width: JoystickWidget.knobSize, height: JoystickWidget.knobSize)
        .offset(x: position.x, y: position.y)
        .blendMode(.destinationOut)
        .scaleEffect(isDragging ? 1.0625 : 1.0)
        .animation(.easeInOut(duration: 0.125), value: isDragging)
        .overlay(
          Circle()
            .fill(Color.white.opacity(0.125))
            .stroke(Color.gray.opacity(0.03125), lineWidth: 5)
            .frame(width: JoystickWidget.knobSize, height: JoystickWidget.knobSize)
            .offset(x: position.x, y: position.y)
            .scaleEffect(isDragging ? 1.0625 : 1.0)
            .animation(.easeInOut(duration: 0.125), value: isDragging)
        )
      }
      .compositingGroup()
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in handleMouseInput(value) }
          .onEnded { _ in handleMouseEnd() }
      )
      .onTapGesture(count: 2) {
        joystick.resetPosition(osc: osc, midi: midi)
      }
    }
    .onAppear {
      startContinuousUpdates()
      if let window = NSApp.windows.first {
        window.makeKeyAndOrderFront(nil)
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
      }
    }
    .onDisappear { cleanup() }
    .padding(.bottom, 64)
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("KeyDown"))) { notif in
        if let key = notif.userInfo?["keyCode"] as? UInt16 {
            if key == 49 { // Spacebar
                joystick.resetPosition(osc: osc, midi: midi)
                return
            }
            pressedKeys.insert(key)
            if let dir = directionFromKeys() {
                handleKeyboardInput(dir)
            }
        }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("KeyUp"))) { notif in
        if let key = notif.userInfo?["keyCode"] as? UInt16 {
            pressedKeys.remove(key)
            if let dir = directionFromKeys() {
                handleKeyboardInput(dir)
            } else {
                handleMouseEnd()
            }
        }
    }
    // --- NYTT: Reagera på gamepad HID-mapping, momentary ---
    .onReceive(gamepad.inputEventPublisher) { event in
        handleGamepadInputEvent(event)
    }
  }

  // --- NYTT: Hantera momentary gamepad-input ---
  @State private var activeActions = Set<JoystickAction>()

  private func handleGamepadInputEvent(_ event: GamepadInputEvent) {
    switch event {
    case .pressed(let input):
        if let action = gamepad.inputMappings[input] {
            activeActions.insert(action)
            updateJoystickForActiveActions()
        }
    case .released(let input):
        if let action = gamepad.inputMappings[input] {
            activeActions.remove(action)
            updateJoystickForActiveActions()
        }
    }
  }

  // Sätt joystick.X/Y beroende på vilka actions som är "aktiva"
  private func updateJoystickForActiveActions() {
    var x: Double = 0
    var y: Double = 0
    if activeActions.contains(.moveLeft) { x -= 1 }
    if activeActions.contains(.moveRight) { x += 1 }
    if activeActions.contains(.moveUp) { y += 1 }
    if activeActions.contains(.moveDown) { y -= 1 }
    joystick.X = x
    joystick.Y = y
    position = CGPoint(x: joystick.X * maxDistance, y: -joystick.Y * maxDistance)
    notifyPositionChange()
    // Reset om reset-action trycks
    if activeActions.contains(.reset) {
        joystick.resetPosition(osc: osc, midi: midi)
        activeActions.remove(.reset)
    }
  }

  private func directionFromKeys() -> CGPoint? {
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    if pressedKeys.contains(123) { dx -= 1 } // vänster
    if pressedKeys.contains(124) { dx += 1 } // höger
    if pressedKeys.contains(125) { dy += 1 } // ner
    if pressedKeys.contains(126) { dy -= 1 } // upp
    if dx == 0 && dy == 0 { return nil }
    let length = sqrt(dx*dx + dy*dy)
    return CGPoint(x: dx/length * maxDistance, y: dy/length * maxDistance)
  }

  private func handleGamepadInput(_ direction: CGPoint) {
    isDragging = true
    position = direction
    notifyPositionChange()
  }

  private func handleKeyboardInput(_ direction: CGPoint) {
    isDragging = true
    position = direction
    notifyPositionChange()
  }

  private func handleMouseInput(_ value: DragGesture.Value) {
    if !isDragging {
      isDragging = true 
    }
    let currentLocation = value.location
    let centerOffset = CGPoint(
      x: currentLocation.x - JoystickWidget.washerSize / 2,
      y: currentLocation.y - JoystickWidget.washerSize / 2
    )
    let distance = sqrt(pow(centerOffset.x, 2) + pow(centerOffset.y, 2))
    if distance <= maxDistance {
      position = centerOffset
    } else {
      let angle = atan2(centerOffset.y, centerOffset.x)
      position = CGPoint(
        x: cos(angle) * maxDistance,
        y: sin(angle) * maxDistance
      )
    }
    notifyPositionChange()
  }
  
  private func handleMouseEnd() {
    isDragging = false
    withAnimation(.easeOut(duration: snapBackSpeed)) {
      position = .zero
    }
  }
  
  private func cleanup() { stopContinuousUpdates() }
  
  private func notifyPositionChange() { onPositionChanged(position) }
  
  private func startContinuousUpdates() {
    stopContinuousUpdates()
    ValueUpdateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
      notifyPositionChange()
    }
  }
  
  private func stopContinuousUpdates() {
    ValueUpdateTimer?.invalidate()
    ValueUpdateTimer = nil
  }
}

struct VirtualJoysticksSettingsView: View {
  @EnvironmentObject var virtualjoysticks: VIRTUALJOYSTICKS
  
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Virtual Joystick Settings")
        .font(.title2)
        .fontWeight(.semibold)
      Text("Configure virtual joysticks for outputting pan and tilt movements.")
        .font(.body)
        .foregroundColor(.secondary)
      Divider()
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("Number of Joysticks:")
            .font(.headline)
          Button(action: {
            if virtualjoysticks.numberOfJoysticks > 1 {
              virtualjoysticks.numberOfJoysticks -= 1
            }
          }) {
            Text("-")
              .font(.title2)
              .frame(width: 18, height: 18)
          }
          .padding(8)
          Text("\(virtualjoysticks.numberOfJoysticks)")
            .font(.title2)
            .frame(width: 16)
          Button(action: {
            if virtualjoysticks.numberOfJoysticks < 8 {
              virtualjoysticks.numberOfJoysticks += 1
            }
          }) {
            Text("+")
              .font(.title2)
              .frame(width: 18, height: 18)
          }
          .padding(8)
          Spacer()
        }
      }
      VStack(alignment: .leading, spacing: 16) {
        TabView {
          ForEach(virtualjoysticks.joystickInstances) { joy in
            JoystickTab(joy: joy)
              .tabItem { Text("Joy \(joy.number)") }
          }
          .frame(height: 72)
          .tabViewStyle(DefaultTabViewStyle())
        }
        Spacer()
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct JoystickTab: View {
  @ObservedObject var joy: VIRTUALJOYSTICKS.JOY
  
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text("Invert X / Pan:")
        Toggle(isOn: $joy.invertX, label: {})
        Spacer().frame(width: 48)
        Text("Invert Y / Tilt:")
        Toggle(isOn: $joy.invertY, label: {})
        Spacer()
      }
      .padding(8)
      HStack {
        Text("Sensitivity:")
          .frame(width: 112, alignment: .leading)
        Slider(value: $joy.sensitivity, in: 0.0001...0.0100)
          .frame(width: 256)
        Text(String(format: "%.2f", joy.sensitivity * 1000))
        Spacer()
      }
      .padding(8)
      HStack {
        Text("Deadzone:")
          .frame(width: 112, alignment: .leading)
        Slider(value: $joy.deadzone, in: 0.0...1.0)
          .frame(width: 256)
        Text(String(format: "%.2f", joy.deadzone))
        Spacer()
      }
      .padding(8)
    }
    .padding()
    .cornerRadius(8)
  }
}
