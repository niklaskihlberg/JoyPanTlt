//
//  VirtualJoystick.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import SwiftUI

struct VirtualJoystick: View {
  @StateObject private var virtualJoystickManager = VirtualJoystickManager.shared
  @StateObject private var keyCommandManager = KeyCommandManager.shared
  @State private var knobPosition: CGPoint = .zero
  @State private var isDragging: Bool = false
  @State private var timer: Timer?
  
  // NY: State för att trigga visuell uppdatering från tangentbord
  @State private var keyboardPosition: CGPoint = .zero
  
  // NY: External position från keyboard control
  @Binding private var externalPosition: CGPoint
  
  // NY: Joystick index för multi-joystick support
  private let joystickIndex: Int
  
  // Input method tracking
  @State private var lastInputMethod: InputMethod = .none
  
  // Callbacks
  let onPositionChanged: (CGPoint) -> Void
  let onInputMethodChanged: ((InputMethod) -> Void)?
  
  // Computed properties for appearance
  private var size: CGFloat { virtualJoystickManager.configuration.joystickSize }
  private var knobSize: CGFloat { virtualJoystickManager.configuration.knobSize }
  private var backgroundColor: Color { Color.gray.opacity(virtualJoystickManager.configuration.backgroundOpacity) }
  private var knobColor: Color { Color.gray.opacity(virtualJoystickManager.configuration.knobOpacity) }
  private var snapBackSpeed: Double { virtualJoystickManager.configuration.snapBackSpeed }
  private var updateInterval: TimeInterval { virtualJoystickManager.configuration.updateInterval }
  
  private var radius: CGFloat { size / 2 }
  private var knobRadius: CGFloat { knobSize / 2 }
  private var maxDistance: CGFloat { radius - knobRadius }
  
  // Current normalized position (unified för både mouse och keyboard)
  private var normalizedPosition: CGPoint {
    return CGPoint(
      x: knobPosition.x / maxDistance,
      y: knobPosition.y / maxDistance
    )
  }
  
  init(
    joystickIndex: Int = 0,
    externalPosition: Binding<CGPoint> = .constant(.zero),
    onPositionChanged: @escaping (CGPoint) -> Void = { _ in },
    onInputMethodChanged: ((InputMethod) -> Void)? = nil
  ) {
    self.joystickIndex = joystickIndex
    self.onPositionChanged = onPositionChanged
    self.onInputMethodChanged = onInputMethodChanged
    self._keyboardPosition = State(initialValue: externalPosition.wrappedValue)
    self._externalPosition = externalPosition
  }
  
  var body: some View {
    VStack(spacing: 15) {
      if virtualJoystickManager.configuration.visualFeedback {
        Text("X: \(normalizedPosition.x, specifier: "%.1f") Y: \(normalizedPosition.y, specifier: "%.1f")")
      }
      
      ZStack {
        // Outer circle (background)
        Circle()
          .fill(Color.white.opacity(0.0625))
          .frame(width: size, height: size)
        
        // Inner circle (knob) - använd bara knobPosition
        Circle()
          .fill(knobColor)
          .frame(width: knobSize, height: knobSize)
          .offset(x: knobPosition.x, y: knobPosition.y)
          .scaleEffect(isDragging ? 1.0625 : 1.0)
          .animation(.easeInOut(duration: 0.125), value: isDragging)
          .shadow(color: Color.black.opacity(0.32), radius: 24, x: 0, y: 0)
          
        Circle() // 3D-Shading
          .fill(RadialGradient(
              gradient: Gradient(colors: [
                Color.white.opacity(0.0625),
                knobColor.opacity(1.0),
                Color.black.opacity(0.0625)
              ]),
              center: UnitPoint(x: 0.3, y: 0.3),
              startRadius: 5,
              endRadius: 50
            ))
          .frame(width: knobSize, height: knobSize)
          .offset(x: knobPosition.x, y: knobPosition.y)
          .scaleEffect(isDragging ? 1.0625 : 1.0)
          .animation(.easeInOut(duration: 0.125), value: isDragging)
      }
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            handleMouseInput(value)
          }
          .onEnded { _ in
            handleMouseEnd()
          }
      )
    }
    .onAppear {
      print("🎹 VirtualJoystick[\(joystickIndex)]: onAppear - simple setup")
      setupKeyCommandCallbacks()
      startContinuousUpdates()
    }
    .onDisappear {
      print("🎹 VirtualJoystick[\(joystickIndex)]: onDisappear - simple cleanup")
      cleanup()
    }
    .onChange(of: virtualJoystickManager.configuration.numberOfJoysticks) { oldCount, newCount in
      print("🎹 VirtualJoystick[\(joystickIndex)]: Joysticks changed from \(oldCount) to \(newCount)")
      
      // NY: ENKEL re-setup utan komplicerade delays
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        self.setupKeyCommandCallbacks()
      }
    }
    .onChange(of: externalPosition) { _, newPosition in
      print("🎹 VirtualJoystick[\(joystickIndex)]: External position changed to \(newPosition)")
      updateKnobFromKeyboard(newPosition)
    }
  }
  
  // MARK: - Setup
  private func setupKeyCommandCallbacks() {
    print("🎹 VirtualJoystick[\(joystickIndex)]: Setting up key command callbacks")
    
    keyCommandManager.setPositionCallback(for: joystickIndex) { position in
      print("🎹 VirtualJoystick[\(self.joystickIndex)] (kb:\(self.joystickIndex)): Received keyboard position: \(position)")
      DispatchQueue.main.async {
        // NY: Konvertera keyboard position till knob position (simulera mouse drag)
        self.updateKnobFromKeyboard(position)
        
        if self.lastInputMethod != .keyboard {
          self.lastInputMethod = .keyboard
          self.onInputMethodChanged?(.keyboard)
        }
        self.notifyPositionChange()
      }
    }
    
    keyCommandManager.setInputMethodCallback(for: joystickIndex) { method in
      DispatchQueue.main.async {
        self.lastInputMethod = method
        self.onInputMethodChanged?(method)
        
        // Reset till centrum när vi lämnar keyboard mode
        if method != .keyboard {
          withAnimation(.easeOut(duration: self.snapBackSpeed)) {
            self.knobPosition = .zero
          }
        }
      }
    }
    
    print("🎹 VirtualJoystick[\(joystickIndex)]: Callbacks registered")
  }
  
  // NY: Konvertera keyboard position till knob position
  private func updateKnobFromKeyboard(_ keyboardPosition: CGPoint) {
    // Konvertera normaliserad keyboard position (-1...1) till faktisk knob position
    let targetX = keyboardPosition.x * maxDistance
    let targetY = keyboardPosition.y * maxDistance
    
    // Begränsa till cirkel-gränser (samma logik som mouse)
    let distance = sqrt(targetX * targetX + targetY * targetY)
    
    let finalPosition: CGPoint
    if distance <= maxDistance {
      finalPosition = CGPoint(x: targetX, y: targetY)
    } else {
      let angle = atan2(targetY, targetX)
      finalPosition = CGPoint(
        x: cos(angle) * maxDistance,
        y: sin(angle) * maxDistance
      )
    }
    
    // Smooth animation till ny position
    withAnimation(.easeInOut(duration: 0.15)) {
      knobPosition = finalPosition
    }
  }
  
  // MARK: - Mouse Input Handling
  private func handleMouseInput(_ value: DragGesture.Value) {
    if lastInputMethod != .mouse {
      lastInputMethod = .mouse
      onInputMethodChanged?(.mouse)
    }
    
    if !isDragging {
      isDragging = true
    }
    
    // ANVÄND SAMMA LOGIK för både första klick och drag
    let currentLocation = value.location
    let centerOffset = CGPoint(
      x: currentLocation.x - size/2,
      y: currentLocation.y - size/2
    )
    
    let distance = sqrt(pow(centerOffset.x, 2) + pow(centerOffset.y, 2))
    
    if distance <= maxDistance {
      knobPosition = centerOffset
    } else {
      let angle = atan2(centerOffset.y, centerOffset.x)
      knobPosition = CGPoint(
        x: cos(angle) * maxDistance,
        y: sin(angle) * maxDistance
      )
    }
    
    notifyPositionChange()
  }
  
  private func handleMouseEnd() {
    isDragging = false
    
    withAnimation(.easeOut(duration: snapBackSpeed)) {
      knobPosition = .zero
    }
  }
  
  // NY: Cleanup när joystick försvinner - FÖRENKLAD
  private func cleanup() {
    stopContinuousUpdates()
    keyCommandManager.clearCallbacks(for: joystickIndex)
  }
  
  // MARK: - Utility Functions
  private func notifyPositionChange() {
    onPositionChanged(normalizedPosition)
  }
  
  private func startContinuousUpdates() {
    stopContinuousUpdates()
    
    timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
      if lastInputMethod == .mouse || keyCommandManager.isKeyboardActive() {
        notifyPositionChange()
      }
    }
  }
  
  private func stopContinuousUpdates() {
    timer?.invalidate()
    timer = nil
  }
}

// MARK: - Preview
struct VirtualJoystick_Previews: PreviewProvider {
  static var previews: some View {
    VStack(spacing: 30) {
      Text("Virtual Joystick Demo")
        .font(.title)
        .padding()
      
      VirtualJoystick { position in
        print("Joystick position: x=\(position.x), y=\(position.y)")
      }
      
      Spacer()
    }
    .padding()
  }
}
