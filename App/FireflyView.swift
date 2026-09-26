import SwiftUI

/// A firefly: a warm glowing body with two soft wings. Unearned ones stay unlit.
struct FireflyView: View {
  var lit = true
  var size: CGFloat = 28

  var body: some View {
    ZStack {
      if lit {
        Circle()
          .fill(RadialGradient(colors: [LabColor.label.opacity(0.55), LabColor.label.opacity(0)], center: .center, startRadius: 0, endRadius: size / 2))
      }
      HStack(spacing: size * 0.02) {
        wing.rotationEffect(.degrees(-24))
        wing.rotationEffect(.degrees(24))
      }
      .offset(y: -size * 0.1)
      Circle()
        .fill(lit ? LabColor.label : LabColor.tertiaryInk.opacity(0.4))
        .frame(width: size * 0.26, height: size * 0.26)
        .shadow(color: lit ? LabColor.label : .clear, radius: size * 0.12)
        .offset(y: size * 0.04)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }

  private var wing: some View {
    Ellipse()
      .fill(lit ? LabColor.softLight.opacity(0.75) : LabColor.tertiaryInk.opacity(0.25))
      .frame(width: size * 0.2, height: size * 0.3)
  }
}
