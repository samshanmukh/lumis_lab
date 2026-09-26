import SwiftUI

/// Show the math: the rule and a table to test it with. The current row follows the live angle.
struct MathPanel: View {
  var liveAngle: Double
  var done: () -> Void

  private let rows: [(angle: Int, lumis: Int)] = [(180, 2), (120, 3), (90, 4), (72, 5), (60, 6), (45, 8)]

  var body: some View {
    let current = rows.min { abs(Double($0.angle) - liveAngle) < abs(Double($1.angle) - liveAngle) }?.angle

    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        HStack {
          Text("The math")
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .foregroundStyle(LabColor.primaryInk)
            .accessibilityAddTraits(.isHeader)
          Spacer()
          Button("Done", action: done)
            .font(LabFont.label)
            .foregroundStyle(LabColor.primaryInk)
            .frame(minWidth: 44, minHeight: 44)
        }

        Text("Lumis = 360° ÷ angle")
          .font(.system(.title2, design: .rounded, weight: .semibold))
          .foregroundStyle(LabColor.lumi)
          .padding(.top, 10)

        Text("A circle is 360°. Each slice is as wide as the mirror angle, and each slice holds one Lumi. That count includes the real Lumi, so reflections = 360° ÷ angle − 1.")
          .font(.system(.subheadline, design: .rounded))
          .foregroundStyle(LabColor.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 10)

        HStack {
          Text("Angle")
          Spacer()
          Text("Lumis")
        }
        .font(LabFont.caption)
        .foregroundStyle(LabColor.tertiaryInk)
        .padding(.horizontal, 12)
        .padding(.top, 18)
        .padding(.bottom, 6)
        .accessibilityHidden(true)

        ForEach(rows, id: \.angle) { row in
          let isCurrent = row.angle == current
          HStack {
            Text("\(row.angle)°")
            Spacer()
            Text("\(row.lumis)")
          }
          .font(.system(.body, design: .rounded, weight: .semibold))
          .monospacedDigit()
          .foregroundStyle(isCurrent ? LabColor.label : LabColor.primaryInk)
          .padding(.horizontal, 12)
          .frame(minHeight: 44)
          .background(isCurrent ? .white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          .overlay(alignment: .bottom) {
            if !isCurrent && row.angle != 45 {
              Rectangle().fill(.white.opacity(0.1)).frame(height: 1).padding(.horizontal, 12)
            }
          }
          .animation(.snappy, value: isCurrent)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("\(row.angle) degrees, \(row.lumis) Lumis")
          .accessibilityAddTraits(isCurrent ? .isSelected : [])
        }
      }
      .padding(28)
    }
    .scrollBounceBehavior(.basedOnSize)
    .background(LabColor.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
    .shadow(color: LabColor.shadow.opacity(0.45), radius: 20, y: 10)
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
  }
}
