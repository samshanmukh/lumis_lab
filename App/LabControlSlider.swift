import SwiftUI

/// One of the Marble Ramp chapter’s lab settings: its name and value over a slider, in the
/// room’s type and inks.
struct LabControlSlider: View {
  var title: String
  @Binding var value: Double
  var range: ClosedRange<Double>
  var minimumLabel: String
  var maximumLabel: String
  var valueLabel: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline) {
        Text(title)
          .foregroundStyle(LabColor.primaryInk)
        Spacer(minLength: 8)
        Text(valueLabel)
          .monospacedDigit()
          .foregroundStyle(LabColor.label)
      }
      .font(.system(.subheadline, design: .rounded, weight: .semibold))
      .accessibilityHidden(true)

      Slider(value: $value, in: range) {
        Text(title)
      } minimumValueLabel: {
        Text(minimumLabel)
          .font(LabFont.barLabel)
          .foregroundStyle(LabColor.tertiaryInk)
      } maximumValueLabel: {
        Text(maximumLabel)
          .font(LabFont.barLabel)
          .foregroundStyle(LabColor.tertiaryInk)
      }
      .accessibilityValue(valueLabel)
    }
  }
}
