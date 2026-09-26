import SwiftUI

struct RampScene: View {
  var model: MarbleChapterModel

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !model.fireflyAwake)) { timeline in
      Canvas { context, size in
        let layout = RampLayout(size: size, angle: model.rampDegrees, mass: model.mass)
        drawSky(in: context, size: size)
        drawLandscape(in: context, layout: layout)
        drawRamp(in: context, layout: layout)
        drawTarget(in: context, layout: layout, date: timeline.date)
        drawBall(in: context, layout: layout)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Marble ramp with a firefly target")
    .accessibilityValue(model.fireflyAwake ? "The marble woke the firefly" : model.isRolling ? "Marble rolling" : "Ready to roll")
  }

  private func drawSky(in context: GraphicsContext, size: CGSize) {
    let background = Path(CGRect(origin: .zero, size: size))
    context.fill(
      background,
      with: .linearGradient(
        Gradient(colors: [Color(red: 0.20, green: 0.18, blue: 0.55), Color(red: 0.11, green: 0.10, blue: 0.34)]),
        startPoint: .zero,
        endPoint: CGPoint(x: size.width * 0.45, y: size.height)
      )
    )

    let moon = CGPoint(x: size.width * 0.56, y: size.height * 0.17)
    let glowSize = min(size.width, size.height) * 0.24
    context.fill(
      Path(ellipseIn: CGRect(x: moon.x - glowSize, y: moon.y - glowSize, width: glowSize * 2, height: glowSize * 2)),
      with: .radialGradient(
        Gradient(colors: [Color(red: 0.91, green: 0.78, blue: 1).opacity(0.18), .clear]),
        center: moon,
        startRadius: 8,
        endRadius: glowSize
      )
    )
    context.fill(Path(ellipseIn: CGRect(x: moon.x - 14, y: moon.y - 14, width: 28, height: 28)), with: .color(Color(red: 1, green: 0.94, blue: 0.75)))

    for star in stars {
      let radius = star.2
      let rect = CGRect(x: size.width * star.0, y: size.height * star.1, width: radius, height: radius)
      context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(radius > 2 ? 0.58 : 0.32)))
    }
  }

  private func drawLandscape(in context: GraphicsContext, layout: RampLayout) {
    let size = layout.size
    let floor = layout.floorY
    var farHill = Path()
    farHill.move(to: CGPoint(x: 0, y: floor - size.height * 0.13))
    farHill.addCurve(
      to: CGPoint(x: size.width, y: floor - size.height * 0.10),
      control1: CGPoint(x: size.width * 0.33, y: floor - size.height * 0.20),
      control2: CGPoint(x: size.width * 0.67, y: floor - size.height * 0.04)
    )
    farHill.addLine(to: CGPoint(x: size.width, y: size.height))
    farHill.addLine(to: CGPoint(x: 0, y: size.height))
    farHill.closeSubpath()
    context.fill(farHill, with: .color(Color(red: 0.27, green: 0.23, blue: 0.65)))

    var nearHill = Path()
    nearHill.move(to: CGPoint(x: 0, y: floor + 12))
    nearHill.addCurve(
      to: CGPoint(x: size.width, y: floor + 12),
      control1: CGPoint(x: size.width * 0.34, y: floor - 24),
      control2: CGPoint(x: size.width * 0.72, y: floor + 28)
    )
    nearHill.addLine(to: CGPoint(x: size.width, y: size.height))
    nearHill.addLine(to: CGPoint(x: 0, y: size.height))
    nearHill.closeSubpath()
    context.fill(nearHill, with: .color(Color(red: 0.24, green: 0.21, blue: 0.61)))

    let ground = CGRect(x: 0, y: floor, width: size.width, height: size.height - floor)
    context.fill(Path(ground), with: .linearGradient(
      Gradient(colors: [Color(red: 0.29, green: 0.25, blue: 0.67), Color(red: 0.17, green: 0.14, blue: 0.47)]),
      startPoint: CGPoint(x: 0, y: floor), endPoint: CGPoint(x: 0, y: size.height)
    ))
    context.stroke(
      Path { path in
        path.move(to: CGPoint(x: 0, y: floor))
        path.addLine(to: CGPoint(x: size.width, y: floor))
      },
      with: .color(Color(red: 0.74, green: 0.68, blue: 1).opacity(0.52)),
      lineWidth: 2
    )
  }

  private func drawRamp(in context: GraphicsContext, layout: RampLayout) {
    var support = Path()
    support.move(to: layout.start)
    support.addLine(to: CGPoint(x: layout.start.x, y: layout.floorY))
    context.stroke(support, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [4, 7]))

    context.stroke(layout.rampPath, with: .color(Color(red: 0.50, green: 0.42, blue: 0.94).opacity(0.45)), style: StrokeStyle(lineWidth: 13, lineCap: .round))
    context.stroke(layout.rampPath, with: .color(Color(red: 0.94, green: 0.90, blue: 1)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
    context.fill(Path(ellipseIn: CGRect(x: layout.start.x - 4, y: layout.start.y - 4, width: 8, height: 8)), with: .color(.white))
  }

  private func drawTarget(in context: GraphicsContext, layout: RampLayout, date: Date) {
    let x = layout.targetX
    let floor = layout.floorY
    let pulse = model.fireflyAwake ? 0.5 + 0.5 * sin(date.timeIntervalSinceReferenceDate * 4) : 0
    let ring = Path(ellipseIn: CGRect(x: x - 24, y: floor - 7, width: 48, height: 14))
    context.fill(ring, with: .color(Color(red: 1, green: 0.75, blue: 0.43).opacity(0.15 + 0.12 * pulse)))
    context.stroke(ring, with: .color(Color(red: 1, green: 0.85, blue: 0.57).opacity(0.8)), style: StrokeStyle(lineWidth: 2, dash: [3, 4]))

    if model.fireflyAwake {
      let radius = 37 + 5 * pulse
      context.fill(
        Path(ellipseIn: CGRect(x: x - radius, y: floor - 43 - radius, width: radius * 2, height: radius * 2)),
        with: .radialGradient(
          Gradient(colors: [Color(red: 1, green: 0.75, blue: 0.35).opacity(0.48), .clear]),
          center: CGPoint(x: x, y: floor - 43), startRadius: 4, endRadius: radius
        )
      )
    }

    let fireflySize: CGFloat = model.fireflyAwake ? 48 : 43
    context.draw(
      Image(model.fireflyAwake ? "Marble_a6448" : "Marble_81b68"),
      in: CGRect(x: x - fireflySize / 2, y: floor - 43 - fireflySize / 2, width: fireflySize, height: fireflySize)
    )
    context.draw(
      Text(model.fireflyAwake ? "AWAKE" : "FIREFLY")
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .tracking(2)
        .foregroundStyle(.white.opacity(0.68)),
      at: CGPoint(x: x, y: floor - 83)
    )
  }

  private func drawBall(in context: GraphicsContext, layout: RampLayout) {
    let point = model.phase == .flat || model.phase == .stopped
      ? CGPoint(x: layout.end.x + model.displayedFlatDistance * layout.size.width,
                y: layout.floorY - layout.ballRadius)
      : layout.ballOnRamp(model.rampProgress)
    let rotation = model.rotation

    let radius = layout.ballRadius
    var ballContext = context
    ballContext.translateBy(x: point.x, y: point.y)
    ballContext.rotate(by: .radians(rotation))
    let circle = Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
    ballContext.fill(
      circle,
      with: .radialGradient(
        Gradient(colors: [Color(red: 1, green: 0.97, blue: 0.83), Color(red: 1, green: 0.72, blue: 0.36), Color(red: 0.76, green: 0.38, blue: 0.29)]),
        center: CGPoint(x: -radius * 0.35, y: -radius * 0.38),
        startRadius: 1,
        endRadius: radius * 1.8
      )
    )
    ballContext.stroke(circle, with: .color(.white.opacity(0.72)), lineWidth: 1)
    ballContext.fill(Path(ellipseIn: CGRect(x: -radius * 0.55, y: -radius * 0.6, width: radius * 0.4, height: radius * 0.4)), with: .color(.white.opacity(0.88)))
    ballContext.fill(Path(ellipseIn: CGRect(x: radius * 0.16, y: radius * 0.08, width: radius * 0.3, height: radius * 0.3)), with: .color(Color(red: 0.70, green: 0.36, blue: 0.25).opacity(0.38)))
  }

  private var stars: [(CGFloat, CGFloat, CGFloat)] {
    [
      (0.05, 0.08, 2), (0.14, 0.19, 1.5), (0.26, 0.08, 2.4), (0.32, 0.21, 1.2),
      (0.43, 0.07, 1.8), (0.54, 0.15, 1.4), (0.62, 0.06, 2.1), (0.74, 0.20, 1.4),
      (0.94, 0.09, 2), (0.08, 0.35, 1.1), (0.28, 0.31, 1.3), (0.58, 0.29, 1.2),
      (0.72, 0.34, 1.7), (0.91, 0.29, 1.2), (0.47, 0.36, 1.1), (0.36, 0.12, 1.2)
    ]
  }
}

private struct RampLayout {
  var size: CGSize
  var angle: Double
  var mass: Double

  var floorY: CGFloat { size.height * 0.77 }
  var run: CGFloat { min(size.width * 0.34, size.height * 0.56 / tan(54 * .pi / 180)) }
  var end: CGPoint { CGPoint(x: size.width * 0.38, y: floorY) }
  var start: CGPoint {
    CGPoint(x: end.x - run, y: floorY - run * tan(angle * .pi / 180))
  }
  var targetX: CGFloat { size.width * MarbleChapterModel.targetFraction }
  var ballRadius: CGFloat {
    min(size.width * 0.027, 10) + min(size.width * 0.035, 13) * CGFloat((mass - 5) / 95)
  }

  var control1: CGPoint {
    CGPoint(x: start.x + run * 0.24, y: start.y + (floorY - start.y) * 0.24)
  }
  var control2: CGPoint {
    CGPoint(x: end.x - run * 0.26, y: floorY)
  }

  var rampPath: Path {
    Path { path in
      path.move(to: start)
      path.addCurve(to: end, control1: control1, control2: control2)
    }
  }

  func ballOnRamp(_ fraction: Double) -> CGPoint {
    let t = CGFloat(fraction)
    let inverse = 1 - t
    let x = inverse * inverse * inverse * start.x
      + 3 * inverse * inverse * t * control1.x
      + 3 * inverse * t * t * control2.x
      + t * t * t * end.x
    let y = inverse * inverse * inverse * start.y
      + 3 * inverse * inverse * t * control1.y
      + 3 * inverse * t * t * control2.y
      + t * t * t * end.y
    let dx = 3 * inverse * inverse * (control1.x - start.x)
      + 6 * inverse * t * (control2.x - control1.x)
      + 3 * t * t * (end.x - control2.x)
    let dy = 3 * inverse * inverse * (control1.y - start.y)
      + 6 * inverse * t * (control2.y - control1.y)
      + 3 * t * t * (end.y - control2.y)
    let length = max(1, hypot(dx, dy))
    return CGPoint(x: x + ballRadius * dy / length, y: y - ballRadius * dx / length)
  }
}
