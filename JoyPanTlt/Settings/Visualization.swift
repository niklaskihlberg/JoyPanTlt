import SwiftUI

struct VisualizationView: View {
  
    @EnvironmentObject var virtualjoysticks: VIRTUALJOYSTICKS

    let circleSize: CGFloat = 200
    let dotSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Visualization")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Show visualization of current Pan and Tilt positions for each joystick.")
                .font(.body)
                .foregroundColor(.secondary)
            TabView {
                ForEach(virtualjoysticks.joystickInstances) { joy in
                    VisualizationJoystickTab(joy: joy)
                        .tabItem { Text("Joy \(joy.number)") }
                }
            }
            .frame(height: 280)
            .tabViewStyle(DefaultTabViewStyle())
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VisualizationJoystickTab: View {
    @ObservedObject var joy: VIRTUALJOYSTICKS.JOY

    let circleSize: CGFloat = 145
    let dotSize: CGFloat = 90

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
              Circle() // Washer
                .fill(joy.flip ? Color.black.opacity(0.0128) : Color.white.opacity(0.0625))
                .stroke(Color.gray.opacity(0.03125), lineWidth: 5)
                .frame(width: circleSize, height: circleSize)

              let x = -CGFloat(joy.X) * (circleSize / 2 - dotSize / 2)
              let y = CGFloat(joy.Y) * (circleSize / 2 - dotSize / 2)
              Circle() // Knob (cut-out)
                .frame(width: dotSize, height: dotSize)
                .offset(x: x, y: y)
                .blendMode(.destinationOut)
                .overlay(
                  Circle()
                    .fill(Color.white.opacity(0.125))
                    .stroke(Color.gray.opacity(0.03125), lineWidth: 5)
                    .frame(width: dotSize, height: dotSize)
                    .offset(x: x, y: y)
                )
            }
            .compositingGroup()
            .frame(height: circleSize)
            Text(String(format: "Pan: %.1f° Tilt: %.1f°", joy.pan, joy.tilt))
                .font(.headline)
        }
        .padding()
    }
}