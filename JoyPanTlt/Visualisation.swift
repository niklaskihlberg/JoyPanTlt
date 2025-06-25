//
//  Visualisation.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import SwiftUI

struct Visualisation: View {
    
  // Pan/Tilt values
  let pan: Double    // -180° to +180° (0° = down, -90° = left, +90° = right, ±180° = up)
  let tilt: Double   // 0° to 90° (0° = center, 90° = edge)
  
  // Customizable properties
  let size: CGFloat
  let knobSize: CGFloat
  let backgroundColor: Color
  let knobColor: Color
  let borderColor: Color
  let borderWidth: CGFloat
  
  // Computed properties
  private var radius: CGFloat { size / 2 }
  private var knobRadius: CGFloat { knobSize / 2 }
  private var maxDistance: CGFloat { radius - knobRadius }
  
  // Calculate knob position based on pan/tilt
  private var knobPosition: CGPoint {
    
    // Convert tilt (0-90°) to distance from center (0 to maxDistance)
    let distance = (tilt / 90.0) * maxDistance
    
    // Convert pan angle to radians
    // Pan: 0° = down, so we need to offset by 90° to align with coordinate system
    let angleInRadians = (pan + 90) * .pi / 180
    
    // Calculate position
    let x = cos(angleInRadians) * distance
    let y = sin(angleInRadians) * distance
    
    return CGPoint(x: x, y: y)

  }
    
  init(
    pan: Double,
    tilt: Double,
    size: CGFloat = 150,
    knobSize: CGFloat = 50,
    backgroundColor: Color = Color.gray.opacity(0.3),
    knobColor: Color = Color.gray,
    borderColor: Color = Color.gray,
    borderWidth: CGFloat = 2
  ) {
    self.pan = pan
    self.tilt = tilt
    self.size = size
    self.knobSize = knobSize
    self.backgroundColor = backgroundColor
    self.knobColor = knobColor
    self.borderColor = borderColor
    self.borderWidth = borderWidth
  }
    
  var body: some View {
      
    ZStack {
      
      // Outer circle (background)
      Circle()
        .fill(backgroundColor)
        .overlay(
          Circle()
            .stroke(borderColor, lineWidth: borderWidth)
        )
        .frame(width: size, height: size)
      
      // // Center dot
      // Circle()
      //   .fill(Color.gray.opacity(0.5))
      //   .frame(width: 4, height: 4)
      
      // Position indicator (knob)
      Circle()
        .fill(knobColor)
        .frame(width: knobSize, height: knobSize)
        .offset(x: knobPosition.x, y: knobPosition.y)
        .shadow(radius: 2)
    }
  }
}

// MARK: - Helper View for displaying values
struct VisualisationWithValues: View {
    
  let pan: Double
  let tilt: Double
  
  var body: some View {
    VStack(spacing: 15) {
      Text("Pan \(pan, specifier: "%.1f")° Tilt: \(tilt, specifier: "%.1f")°")
        .font(.headline)
      
      Visualisation(pan: pan, tilt: tilt)
      
      .foregroundColor(.secondary)
    }
  }
}





// MARK: - Preview
struct Visualisation_Previews: PreviewProvider {
  static var previews: some View {
      VStack(spacing: 30) {
          Text("Pan/Tilt Visualisation Demo")
              .font(.title)
              .padding()
          
          // Different positions
          HStack(spacing: 20) {
              VStack {
                  Text("Center")
                      .font(.caption)
                  Visualisation(pan: 0, tilt: 0)
              }
              
              VStack {
                  Text("Down, Full Tilt")
                      .font(.caption)
                  Visualisation(pan: 0, tilt: 90)
              }
              
              VStack {
                  Text("Left, Half Tilt")
                      .font(.caption)
                  Visualisation(pan: -90, tilt: 45)
              }
          }
          
          HStack(spacing: 20) {
              VStack {
                  Text("Right, Full Tilt")
                      .font(.caption)
                  Visualisation(pan: 90, tilt: 90)
              }
              
              VStack {
                  Text("Up, Half Tilt")
                      .font(.caption)
                  Visualisation(pan: 180, tilt: 45)
              }
              
              VStack {
                  Text("Up Left, Full Tilt")
                      .font(.caption)
                  Visualisation(pan: -135, tilt: 90)
              }
          }
          
          Spacer()
      }
      .padding()
  }
}

