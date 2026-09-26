import SwiftUI

/// A room’s math sheet: the rule, one plain sentence, and a table to test it with.
struct MathSheet {
  struct Row {
    /// The live value this row stands for; the nearest row is the current one.
    var key: Double
    var left: String
    var right: String
    var spoken: String
  }

  var formula: String
  var formulaInk: Color
  var explanation: String
  var columns: (left: String, right: String)
  var rows: [Row]

  static let mirror = MathSheet(
    formula: "Lumis = 360° ÷ angle",
    formulaInk: LabColor.lumi,
    explanation: "A circle is 360°. Each slice is as wide as the mirror angle, and each slice holds one Lumi. That count includes the real Lumi, so reflections = 360° ÷ angle − 1.",
    columns: ("Angle", "Lumis"),
    rows: [(180, 2), (120, 3), (90, 4), (72, 5), (60, 6), (45, 8)].map { angle, lumis in
      Row(key: Double(angle), left: "\(angle)°", right: "\(lumis)", spoken: "\(angle) degrees, \(lumis) Lumis")
    }
  )

  /// The Glass Pond: Snell’s law with n = 1.5, glass angle to air angle.
  static let pond = MathSheet(
    formula: "1.5 × sin(glass angle) = sin(air angle)",
    formulaInk: LabColor.glassAqua,
    explanation: "Glass bends light. When the air angle would pass 90°, the light can’t leave. (Water tips at about 49°, diamond at 24°.)",
    columns: ("Glass angle", "Air angle"),
    rows: [
      Row(key: 10, left: "10°", right: "15°", spoken: "10 degrees in glass, 15 degrees in air"),
      Row(key: 20, left: "20°", right: "31°", spoken: "20 degrees in glass, 31 degrees in air"),
      Row(key: 30, left: "30°", right: "49°", spoken: "30 degrees in glass, 49 degrees in air"),
      Row(key: 40, left: "40°", right: "75°", spoken: "40 degrees in glass, 75 degrees in air"),
      Row(key: GlassOptics.criticalAngle, left: "41.8°", right: "90° · skims", spoken: "41.8 degrees in glass, 90 degrees, it skims the surface"),
      Row(key: 48, left: "48°", right: "stays inside", spoken: "48 degrees in glass, the light stays inside")
    ]
  )
}

/// Show the math: the rule and a table to test it with. The current row follows the live value.
struct MathPanel: View {
  var sheet = MathSheet.mirror
  var liveValue: Double
  var done: () -> Void

  var body: some View {
    let current = sheet.rows.indices.min { abs(sheet.rows[$0].key - liveValue) < abs(sheet.rows[$1].key - liveValue) }

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

        Text(sheet.formula)
          .font(.system(.title2, design: .rounded, weight: .semibold))
          .foregroundStyle(sheet.formulaInk)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 10)

        Text(sheet.explanation)
          .font(.system(.subheadline, design: .rounded))
          .foregroundStyle(LabColor.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 10)

        HStack {
          Text(sheet.columns.left)
          Spacer()
          Text(sheet.columns.right)
        }
        .font(LabFont.caption)
        .foregroundStyle(LabColor.tertiaryInk)
        .padding(.horizontal, 12)
        .padding(.top, 18)
        .padding(.bottom, 6)
        .accessibilityHidden(true)

        ForEach(sheet.rows.indices, id: \.self) { index in
          let row = sheet.rows[index]
          let isCurrent = index == current
          HStack {
            Text(row.left)
            Spacer()
            Text(row.right)
          }
          .font(.system(.body, design: .rounded, weight: .semibold))
          .monospacedDigit()
          .foregroundStyle(isCurrent ? LabColor.label : LabColor.primaryInk)
          .padding(.horizontal, 12)
          .frame(minHeight: 44)
          .background(isCurrent ? .white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          .overlay(alignment: .bottom) {
            if !isCurrent && index != sheet.rows.count - 1 {
              Rectangle().fill(.white.opacity(0.1)).frame(height: 1).padding(.horizontal, 12)
            }
          }
          .animation(.snappy, value: isCurrent)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(row.spoken)
          .accessibilityAddTraits(isCurrent ? .isSelected : [])
        }
      }
      .padding(28)
    }
    .scrollBounceBehavior(.basedOnSize)
    .background(LabColor.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1))
    .shadow(color: LabColor.shadow.opacity(0.45), radius: 20, y: 10)
    .accessibilityElement(children: .contain)
    .accessibilityAddTraits(.isModal)
  }
}
