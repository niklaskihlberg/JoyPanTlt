//
//  ContentView.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-25.
//

import SwiftUI

struct ContentView: View {
  @State private var pan: Double = 0.0    // -180° to +180°
  @State private var tilt: Double = 0.0   // 0° to 90°
  
  var body: some View {
    VStack(spacing: 40) {
      
      // Joystick för kontroll
      VirtualJoystick(updateInterval: 0.05) { position in // 20 gånger per sekund
        let result = TranslationLogic.convertJoystickToPanTilt(position)
        pan = result.pan
        tilt = result.tilt
      }
      
      // Reset-knapp
      Button("Reset Pan/Tilt") {
        TranslationLogic.resetAccumulation()
        pan = 0.0
        tilt = 0.0
      }
      .padding()
      // .background(Color.gray.opacity(0.2))
      .cornerRadius(8)
      
      // Visualiseringscirkel
      VisualisationWithValues(pan: pan, tilt: tilt)
      
      
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
