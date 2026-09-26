import SwiftUI

/// A labelled slider for one of the lab’s settings, with its value in lemon ink.
struct LabControlSlider: View {
  var title: String
  @Binding var value: Double
  var range: ClosedRange<Double>
  var minimumLabel: String
  var maximumLabel: String
  var valueLabel: String

  var body: some View {
    VStack(spacing: 2) {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .font(.system(.subheadline, design: .rounded, weight: .semibold))
          .foregroundStyle(LabColor.primaryInk)
        Spacer()
        Text(valueLabel)
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .monospacedDigit()
          .foregroundStyle(LabColor.label)
      }
      Slider(value: $value, in: range) {
        Text(title)
      } minimumValueLabel: {
        Text(minimumLabel).font(LabFont.barLabel).foregroundStyle(LabColor.tertiaryInk)
      } maximumValueLabel: {
        Text(maximumLabel).font(LabFont.barLabel).foregroundStyle(LabColor.tertiaryInk)
      }
      .tint(LabColor.retry)
      .accessibilityValue(valueLabel)
    }
  }
}
