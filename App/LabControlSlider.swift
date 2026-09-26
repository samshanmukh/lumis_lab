import SwiftUI

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
        Spacer()
        Text(valueLabel)
          .font(.system(.subheadline, design: .rounded, weight: .bold))
          .monospacedDigit()
          .foregroundStyle(Color(red: 1, green: 0.86, blue: 0.63))
      }
      Slider(value: $value, in: range) {
        Text(title)
      } minimumValueLabel: {
        Text(minimumLabel).font(.caption2)
      } maximumValueLabel: {
        Text(maximumLabel).font(.caption2)
      }
      .tint(Color(red: 0.88, green: 0.77, blue: 1))
      .accessibilityValue(valueLabel)
    }
  }
}
