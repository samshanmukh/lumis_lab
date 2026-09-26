import SwiftUI

enum LumiMood {
  case calm
  case happy
  case worried
  case wonder
  case sleepy
}

struct LumiView: View {
  var mood: LumiMood
  var radius: CGFloat = 40
  var mirrored = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var breathing = false

  var body: some View {
    ZStack {
      Circle()
        .fill(LabColor.glow.opacity(0.34))
        .frame(width: radius * 2.7, height: radius * 2.7)
        .blur(radius: radius * 0.38)

      Circle()
        .fill(RadialGradient(
          colors: [LabColor.softLight, LabColor.lumi, LabColor.glow],
          center: .init(x: 0.35, y: 0.3),
          startRadius: 1,
          endRadius: radius
        ))
        .frame(width: radius * 2, height: radius * 2)
        .overlay(alignment: .topTrailing) {
          Circle()
            .trim(from: 0.12, to: 0.83)
            .stroke(LabColor.lumi, style: StrokeStyle(lineWidth: radius * 0.13, lineCap: .round))
            .frame(width: radius * 0.35, height: radius * 0.38)
            .rotationEffect(.degrees(-28))
            .offset(x: -radius * 0.13, y: -radius * 0.15)
        }

      face
        .frame(width: radius * 1.12, height: radius * 0.75)
        .offset(y: radius * 0.15)
    }
    .frame(width: radius * 2.7, height: radius * 2.7)
    .scaleEffect(x: (mirrored ? -1 : 1) * (breathing ? 1.03 : 1), y: breathing ? 1.03 : 1)
    .onAppear { breathe(!reduceMotion) }
    .onChange(of: reduceMotion) { _, reduce in breathe(!reduce) }
    .accessibilityLabel("Lumi, \(String(describing: mood))")
  }

  /// Breathing: scale 1 → 1.03 over 3 s, on a loop.
  private func breathe(_ on: Bool) {
    if on {
      withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { breathing = true }
    } else {
      var transaction = Transaction()
      transaction.disablesAnimations = true
      withTransaction(transaction) { breathing = false }
    }
  }

  private var face: some View {
    VStack(spacing: radius * 0.07) {
      HStack(spacing: radius * 0.38) {
        eye
        eye
      }
      mouth
    }
  }

  @ViewBuilder
  private var eye: some View {
    if mood == .sleepy {
      Capsule().fill(Color(hexValue: 0x5F365F)).frame(width: radius * 0.19, height: radius * 0.055)
    } else {
      Ellipse().fill(Color(hexValue: 0x5F365F)).frame(width: radius * 0.11, height: radius * 0.17)
    }
  }

  @ViewBuilder
  private var mouth: some View {
    switch mood {
    case .happy:
      Path { path in
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: radius * 0.28, y: 0), control: CGPoint(x: radius * 0.14, y: radius * 0.2))
      }
      .stroke(Color(hexValue: 0x8B4A65), style: StrokeStyle(lineWidth: 2, lineCap: .round))
      .frame(width: radius * 0.28, height: radius * 0.2)
    case .worried:
      Ellipse().stroke(Color(hexValue: 0x8B4A65), lineWidth: 2)
        .frame(width: radius * 0.12, height: radius * 0.13)
    case .wonder:
      Ellipse().fill(Color(hexValue: 0x8B4A65)).frame(width: radius * 0.1, height: radius * 0.13)
    case .calm, .sleepy:
      Capsule().fill(Color(hexValue: 0x8B4A65)).frame(width: radius * 0.17, height: radius * 0.04)
    }
  }
}

private extension Color {
  init(hexValue: UInt32) {
    self.init(red: Double((hexValue >> 16) & 255) / 255, green: Double((hexValue >> 8) & 255) / 255, blue: Double(hexValue & 255) / 255)
  }
}
