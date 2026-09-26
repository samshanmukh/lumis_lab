import SwiftUI

/// The mirror angle, top trailing, with an optional goal pill underneath.
struct AngleReadout: View {
  var angle: Double
  var goal: Double?
  var goalMet = false

  @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 44

  var body: some View {
    VStack(alignment: .trailing, spacing: 2) {
      Text("\(Int(angle.rounded()))°")
        .font(.system(size: size, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(LabColor.primaryInk)
        .contentTransition(.numericText(value: angle))
      Text("mirror angle")
        .font(LabFont.caption)
        .foregroundStyle(LabColor.tertiaryInk)
      if let goal {
        SceneLabel(text: "goal \(Int(goal))°", kind: .goal(met: goalMet))
          .padding(.top, 8)
          .animation(.easeInOut(duration: 0.2), value: goalMet)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Mirror angle")
    .accessibilityValue(accessibilityValue)
    .accessibilityAddTraits(.updatesFrequently)
  }

  private var accessibilityValue: String {
    var value = "\(Int(angle.rounded())) degrees"
    if let goal { value += goalMet ? ", goal \(Int(goal)) degrees reached" : ", goal \(Int(goal)) degrees" }
    return value
  }
}
