import SwiftUI

/// The night sky behind most screens. Stars twinkle (opacity 0.4–1 over 3–6 s) and a few
/// fireflies drift on 8 s loops. Everything holds still with Reduce Motion.
struct LabBackdrop: View {
  var showsFireflies = true

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      LabColor.background
      TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
        let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
        Canvas { context, size in
          drawStars(at: time, in: &context, size: size)
          if showsFireflies {
            drawFireflies(at: time, in: &context, size: size)
          }
        }
      }
      .accessibilityHidden(true)
    }
    .ignoresSafeArea()
  }

  private func drawStars(at time: TimeInterval, in context: inout GraphicsContext, size: CGSize) {
    for index in 0..<76 {
      let x = CGFloat((index * 137 + 47) % 997) / 997 * size.width
      let y = CGFloat((index * 281 + 79) % 991) / 991 * size.height
      let diameter: CGFloat = index % 9 == 0 ? 3 : 1.5
      let period = 3 + 3 * Double((index * 61) % 100) / 100
      let wave = 0.5 + 0.5 * sin(2 * .pi * time / period + Double(index) * 1.7)
      let twinkle = 0.4 + 0.6 * wave
      let brightness = index % 3 == 0 ? 0.95 : 0.5
      context.fill(
        Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
        with: .color(LabColor.secondaryInk.opacity(brightness * twinkle))
      )
    }
  }

  private static let fireflies: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
    (0.08, 0.2, 13), (0.86, 0.12, 15), (0.72, 0.46, 12), (0.18, 0.72, 14), (0.92, 0.82, 12)
  ]

  /// Each drift is built from whole harmonics of an 8 s loop, so the path repeats seamlessly.
  private func drawFireflies(at time: TimeInterval, in context: inout GraphicsContext, size: CGSize) {
    let loop = 2 * .pi * time / 8
    for (index, firefly) in Self.fireflies.enumerated() {
      let phase = Double(index) * 1.9
      let dx = 22 * sin(loop + phase) + 9 * sin(2 * loop + phase * 2)
      let dy = 14 * cos(loop + phase * 1.3) + 6 * sin(3 * loop + phase)
      let center = CGPoint(x: firefly.x * size.width + dx, y: firefly.y * size.height + dy)
      let glowPulse = 0.7 + 0.3 * sin(4 * loop + phase)
      let radius = firefly.size

      context.fill(
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
        with: .radialGradient(
          Gradient(colors: [LabColor.label.opacity(0.45 * glowPulse), LabColor.label.opacity(0)]),
          center: center,
          startRadius: 0,
          endRadius: radius
        )
      )
      for side in [-1.0, 1.0] {
        var wing = context
        wing.translateBy(x: center.x + side * radius * 0.16, y: center.y - radius * 0.18)
        wing.rotate(by: .degrees(side * 24))
        wing.fill(
          Path(ellipseIn: CGRect(x: -radius * 0.1, y: -radius * 0.16, width: radius * 0.2, height: radius * 0.32)),
          with: .color(LabColor.softLight.opacity(0.6))
        )
      }
      let body = radius * 0.28
      context.fill(
        Path(ellipseIn: CGRect(x: center.x - body / 2, y: center.y - body / 2, width: body, height: body)),
        with: .color(LabColor.label)
      )
    }
  }
}
