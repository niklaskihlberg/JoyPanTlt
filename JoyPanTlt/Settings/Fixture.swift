import SwiftUI

struct FixtureSettingsView: View {
    @EnvironmentObject var virtualjoysticks: VIRTUALJOYSTICKS

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Fixture Settings")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Set modifier settings for each joystick.")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.bottom, 56.0)
            
            TabView {
                ForEach(virtualjoysticks.joystickInstances.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Min Pan:")
                              .modifier(PlainText())
                            DegreeTextField(placeholder: "90", value: $virtualjoysticks.joystickInstances[index].minPan)
                            // TextField("-180", value: $virtualjoysticks.joystickInstances[index].minPan, formatter: NumberFormatter())
                            //     .modifier(NumericFieldStyle())
                                .padding(.trailing, 16)
                            Text("Max Pan:")
                              .modifier(PlainText())
                            DegreeTextField(placeholder: "90", value: $virtualjoysticks.joystickInstances[index].maxPan)
                            // TextField("180", value: $virtualjoysticks.joystickInstances[index].maxPan, formatter: NumberFormatter())
                            //     .modifier(NumericFieldStyle())
                        }
                        HStack {
                            Text("Min Tilt:")
                              .modifier(PlainText())
                            DegreeTextField(placeholder: "270", value: $virtualjoysticks.joystickInstances[index].minTilt)
                            // TextField("0", value: $virtualjoysticks.joystickInstances[index].minTilt, formatter: NumberFormatter())
                            //     .modifier(NumericFieldStyle())
                                .padding(.trailing, 16)
                            Text("Max Tilt:")
                              .modifier(PlainText())
                            DegreeTextField(placeholder: "90", value: $virtualjoysticks.joystickInstances[index].maxTilt)
                            // TextField("90", value: $virtualjoysticks.joystickInstances[index].maxTilt, formatter: NumberFormatter())
                            //     .modifier(NumericFieldStyle())
                        }
                        .padding(.bottom, 8)

                        HStack {
                            Text("Rotation offset:")
                                .frame(width: 96)
                            DegreeTextField(
                                placeholder: "0",
                                value: $virtualjoysticks.joystickInstances[index].rotationOffset,
                                minInput: -179,
                                maxInput: 180
                            )
                            RotationOffsetVisualizer(offset: $virtualjoysticks.joystickInstances[index].rotationOffset)
                                .padding(.leading, 8)
                        }
                        .padding(.bottom, 8)

                        HStack {
                          Text("Allow 'Foldover/Flip':")
                          Toggle(isOn: $virtualjoysticks.joystickInstances[index].allowFlip, label: {})
                          Spacer()
                        }
                    }
                    .padding()
                    .tabItem { Text("Joy \(index + 1)") }
                }
            }
            .frame(height: 120)
            .tabViewStyle(DefaultTabViewStyle())
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}





struct PlainText: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 56)
            .multilineTextAlignment(.trailing)
    }
}

struct DegreeTextField: View {
    let placeholder: String
    @Binding var value: Double
    var minInput: Double = -1080
    var maxInput: Double = 1080

    var body: some View {
        HStack(spacing: 0) {
            TextField(placeholder, value: Binding(
                get: { value },
                set: { newValue in
                    value = min(max(newValue, minInput), maxInput)
                }
            ), formatter: DegreeFormatter())
            .frame(width: 72)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .monospaced()
            .multilineTextAlignment(.center)
        }
    }
}

class DegreeFormatter: NumberFormatter, @unchecked Sendable{
    override func string(for obj: Any?) -> String? {
        if let number = obj as? NSNumber {
            return "\(number.intValue)°"
        }
        return super.string(for: obj)
    }
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        let cleaned = string.replacingOccurrences(of: "°", with: "")
        return super.getObjectValue(obj, for: cleaned, errorDescription: error)
    }
}

struct RotationOffsetVisualizer: View {
    @Binding var offset: Double // grader, bind till joystick.rotationOffset

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 5)
                // Noll-linje (neråt)
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 5, height: 16)
                    .offset(y: -10)
                    .rotationEffect(.degrees(180))
                // Offset-markör
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 5, height: 18)
                    .cornerRadius(2.5)
                    .offset(y: -10)
                    .rotationEffect(.degrees(offset.wrappedDegree + 180))
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let angle = atan2(dy, dx) * 180 / .pi
                        // Gör så att 0° är nedåt:
                        let adjusted = (angle - 90)
                        // Wrappa till -179...180
                        offset = Double(adjusted).wrappedDegree
                    }
            )
        }
        .frame(width: 32, height: 32)
    }
}

extension Double {
    /// Wrappar till intervallet (-180, 180], så att 180° är möjligt men -180° blir 180°
    var wrappedDegree: Double {
        var deg = self.truncatingRemainder(dividingBy: 360)
        if deg < -180 { deg += 360 }
        if deg > 180 { deg -= 360 }
        // Om nära 180 eller -180, returnera exakt 180
        if deg >= 179.5 || deg <= -179.5 {
            return 180
        }
        return deg
    }
}
