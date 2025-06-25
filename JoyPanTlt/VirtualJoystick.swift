//
//  VirtualJoystick.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import SwiftUI

struct VirtualJoystick: View {
  // Joystick properties
  @State private var knobPosition: CGPoint = .zero
  @State private var isDragging: Bool = false
  @State private var timer: Timer?
  
  // Customizable properties
  let size: CGFloat
  let knobSize: CGFloat
  let backgroundColor: Color
  let knobColor: Color
  let borderColor: Color
  let borderWidth: CGFloat
  let updateInterval: TimeInterval
  
  // Callback for position changes
  let onPositionChanged: (CGPoint) -> Void
  
  // Computed properties
  private var radius: CGFloat { size / 2 }
  private var knobRadius: CGFloat { knobSize / 2 }
  private var maxDistance: CGFloat { radius - knobRadius }
  
  // Current normalized position
  private var normalizedPosition: CGPoint {
    CGPoint(
      x: knobPosition.x / maxDistance,
      y: knobPosition.y / maxDistance
    )
  }
  
  init(
    size: CGFloat = 150,
    knobSize: CGFloat = 50,
    backgroundColor: Color = Color.gray.opacity(0.3),
    knobColor: Color = Color.gray,
    borderColor: Color = Color.gray,
    borderWidth: CGFloat = 2,
    updateInterval: TimeInterval = 0.1,
    onPositionChanged: @escaping (CGPoint) -> Void = { _ in }
  ) {
    self.size = size
    self.knobSize = knobSize
    self.backgroundColor = backgroundColor
    self.knobColor = knobColor
    self.borderColor = borderColor
    self.borderWidth = borderWidth
    self.updateInterval = updateInterval
    self.onPositionChanged = onPositionChanged
  }
  
  var body: some View {
    VStack(spacing: 15) {
      Text("X: \(normalizedPosition.x, specifier: "%.1f") Y: \(normalizedPosition.y, specifier: "%.1f")")
        .font(.headline)
      
      ZStack {
        // Outer circle (background)
        Circle()
          .fill(backgroundColor)
          .overlay(
            Circle()
              .stroke(borderColor, lineWidth: borderWidth)
          )
          .frame(width: size, height: size)
        
        // Inner circle (knob)
        Circle()
          .fill(knobColor)
          .frame(width: knobSize, height: knobSize)
          .offset(x: knobPosition.x, y: knobPosition.y)
          .scaleEffect(isDragging ? 1.1 : 1.0)
          .animation(.easeInOut(duration: 0.1), value: isDragging)
      }
      .gesture(
        DragGesture()
          .onChanged { value in
            if !isDragging {
              isDragging = true
            }
            
            let translationPoint = CGPoint(x: value.translation.width, y: value.translation.height)
            let distance = sqrt(pow(translationPoint.x, 2) + pow(translationPoint.y, 2))
            
            if distance <= maxDistance {
              knobPosition = translationPoint
            } else {
              let angle = atan2(translationPoint.y, translationPoint.x)
              knobPosition = CGPoint(
                x: cos(angle) * maxDistance,
                y: sin(angle) * maxDistance
              )
            }
          }
          .onEnded { _ in
            isDragging = false
            withAnimation(.easeOut(duration: 0.3)) {
              knobPosition = .zero
            }
          }
      )
      .onAppear {
        startContinuousUpdates()
      }
      .onDisappear {
        stopContinuousUpdates()
      }
    }
  }
  
  // MARK: - Timer Functions
  private func startContinuousUpdates() {
    stopContinuousUpdates()
    
    timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
      onPositionChanged(normalizedPosition)
    }
  }
  
  private func stopContinuousUpdates() {
    timer?.invalidate()
    timer = nil
  }
}

// MARK: - Helper Extensions
extension CGPoint {
  var magnitude: CGFloat {
    sqrt(x * x + y * y)
  }
  
  func normalized() -> CGPoint {
    let mag = magnitude
    return mag > 0 ? CGPoint(x: x / mag, y: y / mag) : .zero
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

