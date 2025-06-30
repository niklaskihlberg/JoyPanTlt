//
//  JoystickGridItem.swift
//  JoyPanTlt
//
//  Created by Niklas Kihlberg on 2025-06-29.
//

import SwiftUI

// MARK: - Joystick Grid Item Component
struct JoystickGridItem: View {
    let joystick: JoystickInstance
    let index: Int
    let size: CGFloat
    let totalJoysticks: Int // NY: Lägg till total antal joysticks
    @Binding var keyboardPosition: CGPoint // Ändra till @Binding
    let onPositionChanged: (CGPoint) -> Void
    
    // Beräkna text-storlek baserat på joystick-storlek
    private var textSize: CGFloat {
        return max(12, size * 0.15) // 15% av joystick-storleken, minst 12pt
    }
    
    var body: some View {
        VStack(spacing: 6) { // Minska spacing från 8 till 6
            // Visa nummer endast om det finns fler än 1 joystick
            if totalJoysticks > 1 {
                Text("\(index + 1)")
                    .font(.system(size: textSize))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: Color.black.opacity(0.7), radius: 2, x: 1, y: 1)
            }
            
            VirtualJoystick(
                joystickIndex: index,  // Skicka med joystick index
                externalPosition: $keyboardPosition, // Skicka som Binding
                onPositionChanged: onPositionChanged,
                onInputMethodChanged: { method in
                    print("🎮 Joystick \(index + 1) input method: \(method)")
                }
            )
            .frame(width: size, height: size)
            .background(Color.clear)
            .cornerRadius(8)
            .id("joystick-\(index)") // Enklare ID utan position tracking
        }
    }
}
