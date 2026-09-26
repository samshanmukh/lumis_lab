import SwiftUI

/// Show the math: the rule and a table to test it with. The current row follows the live angle.
struct MathPanel: View {
  var formula: String
  var explanation: String
  var columns: (leading: String, trailing: String)
  var rows: [MathRow]
  var liveAngle: Double
  var done: () -> Void

  var body: some View {
    let current = rows.min { abs($0.angle - liveAngle) < abs($1.angle - liveAngle) }?.angle

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

        Text(formula)
          .font(.system(.title2, design: .rounded, weight: .semibold))
          .foregroundStyle(LabColor.lumi)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 10)

        Text(explanation)
          .font(.system(.subheadline, design: .rounded))
          .foregroundStyle(LabColor.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 10)

        HStack {
          Text(columns.leading)
          Spacer()
          Text(columns.trailing)
        }
        .font(LabFont.caption)
        .foregroundStyle(LabColor.tertiaryInk)
        .padding(.horizontal, 12)
        .padding(.top, 18)
        .padding(.bottom, 6)
        .accessibilityHidden(true)

        ForEach(rows) { row in
          let isCurrent = row.angle == current
          HStack {
            Text("\(Int(row.angle))°")
            Spacer()
            Text(row.value)
          }
          .font(.system(.body, design: .rounded, weight: .semibold))
          .monospacedDigit()
          .foregroundStyle(isCurrent ? LabColor.label : LabColor.primaryInk)
          .padding(.horizontal, 12)
          .frame(minHeight: 44)
          .background(isCurrent ? .white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          .overlay(alignment: .bottom) {
            if !isCurrent && row.id != rows.last?.id {
              Rectangle().fill(.white.opacity(0.1)).frame(height: 1).padding(.horizontal, 12)
            }
          }
          .animation(.snappy, value: isCurrent)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("\(Int(row.angle)) degrees, \(row.spokenValue)")
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

struct MathRow: Identifiable {
  var angle: Double
  var value: String
  var spokenValue: String

  var id: Double { angle }
}

extension MathPanel {
  /// 5.5: Lumis = 360° ÷ angle.
  static func mirror(liveAngle: Double, done: @escaping () -> Void) -> MathPanel {
    MathPanel(
      formula: "Lumis = 360° ÷ angle",
      explanation: "A circle is 360°. Each slice is as wide as the mirror angle, and each slice holds one Lumi. That count includes the real Lumi, so reflections = 360° ÷ angle − 1.",
      columns: ("Angle", "Lumis"),
      rows: [(180, 2), (120, 3), (90, 4), (72, 5), (60, 6), (45, 8)].map {
        MathRow(angle: $0.0, value: "\($0.1)", spokenValue: "\($0.1) Lumis")
      },
      liveAngle: liveAngle,
      done: done
    )
  }

  /// 5.8: speed at the bottom = √(10/7 × g × height), for a 10 cm drop.
  static func marbleRamp(liveAngle: Double, done: @escaping () -> Void) -> MathPanel {
    MathPanel(
      formula: "speed at the bottom = √(10/7 × g × height)",
      explanation: "Height turns into speed. The angle isn’t in the formula, so from the same height every smooth ramp gives the same speed. Steeper just gets there sooner.",
      columns: ("Ramp (10 cm drop)", "Time down · speed at the bottom"),
      rows: [(15, "0.65"), (20, "0.49"), (30, "0.34"), (40, "0.26"), (45, "0.24"), (50, "0.22")].map {
        MathRow(angle: $0.0, value: "\($0.1) s · 1.2 m/s", spokenValue: "\($0.1) seconds down, 1.2 meters per second at the bottom")
      },
      liveAngle: liveAngle,
      done: done
    )
  }
}
