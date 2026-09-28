import SwiftUI

enum LumiMood {
  case calm
  case happy
  case worried
  case wonder
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

      LumiFace(mood: mood, radius: radius)
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
}

/// Lumi’s face: big shining eyes, rosy cheeks, and a mouth for the mood. Every mood keeps her
/// eyes open and her mouth curved, so she always looks awake and friendly. Positions are
/// fractions of her radius from the middle of her body.
private struct LumiFace: View {
  var mood: LumiMood
  var radius: CGFloat

  private static let ink = Color(hexValue: 0x5F365F)
  private static let mouthInk = Color(hexValue: 0x7A3A58)
  private static let tongue = Color(hexValue: 0xFF8FA8)
  private static let cheek = Color(hexValue: 0xFF9DB0)

  var body: some View {
    ZStack {
      ForEach([-1.0, 1.0], id: \.self) { side in
        cheek
          .offset(x: side * radius * 0.52, y: radius * 0.26)
        eye
          .offset(x: side * radius * 0.3, y: radius * 0.04)
        if mood == .worried {
          // Brows lifted at the middle.
          Capsule()
            .fill(Self.ink)
            .frame(width: radius * 0.15, height: max(1.5, radius * 0.045))
            .rotationEffect(.degrees(side * 18))
            .offset(x: side * radius * 0.29, y: -radius * 0.17)
        }
      }
      mouth
        .offset(y: radius * 0.3)
    }
    .accessibilityHidden(true)
  }

  private var cheek: some View {
    Ellipse()
      .fill(Self.cheek.opacity(0.5))
      .frame(width: radius * 0.26, height: radius * 0.14)
      .blur(radius: radius * 0.02)
  }

  /// A round, shining eye; wider still when Lumi is amazed.
  private var eye: some View {
    let size = mood == .wonder
      ? CGSize(width: radius * 0.2, height: radius * 0.26)
      : CGSize(width: radius * 0.18, height: radius * 0.23)
    return Ellipse()
      .fill(Self.ink)
      .frame(width: size.width, height: size.height)
      .overlay {
        Circle()
          .fill(.white)
          .frame(width: radius * 0.08, height: radius * 0.08)
          .offset(x: radius * 0.035, y: -radius * 0.05)
        Circle()
          .fill(.white.opacity(0.85))
          .frame(width: radius * 0.04, height: radius * 0.04)
          .offset(x: -radius * 0.04, y: radius * 0.055)
      }
  }

  @ViewBuilder
  private var mouth: some View {
    switch mood {
    case .happy:
      // A wide open smile with a little tongue.
      let smile = OpenSmile()
      ZStack(alignment: .bottom) {
        smile.fill(Self.mouthInk)
        Ellipse()
          .fill(Self.tongue)
          .frame(width: radius * 0.15, height: radius * 0.09)
          .offset(y: radius * 0.02)
      }
      .frame(width: radius * 0.3, height: radius * 0.17)
      .clipShape(smile)
    case .calm:
      SoftSmile()
        .stroke(Self.mouthInk, style: StrokeStyle(lineWidth: max(1.5, radius * 0.055), lineCap: .round))
        .frame(width: radius * 0.22, height: radius * 0.08)
    case .wonder:
      Ellipse()
        .fill(Self.mouthInk)
        .frame(width: radius * 0.12, height: radius * 0.15)
    case .worried:
      Ellipse()
        .fill(Self.mouthInk)
        .frame(width: radius * 0.12, height: radius * 0.09)
    }
  }
}

/// A smile open at the top, curving deep at the bottom.
private struct OpenSmile: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      path.move(to: CGPoint(x: rect.minX, y: rect.minY))
      path.addQuadCurve(
        to: CGPoint(x: rect.maxX, y: rect.minY),
        control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.12)
      )
      path.addQuadCurve(
        to: CGPoint(x: rect.minX, y: rect.minY),
        control: CGPoint(x: rect.midX, y: rect.maxY * 2 - rect.minY)
      )
      path.closeSubpath()
    }
  }
}

/// A closed, gentle smile.
private struct SoftSmile: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      path.move(to: CGPoint(x: rect.minX, y: rect.minY))
      path.addQuadCurve(
        to: CGPoint(x: rect.maxX, y: rect.minY),
        control: CGPoint(x: rect.midX, y: rect.maxY * 2 - rect.minY)
      )
    }
  }
}

private extension Color {
  init(hexValue: UInt32) {
    self.init(red: Double((hexValue >> 16) & 255) / 255, green: Double((hexValue >> 8) & 255) / 255, blue: Double(hexValue & 255) / 255)
  }
}
