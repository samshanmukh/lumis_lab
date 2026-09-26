import SwiftUI

struct PondSceneView: View {
  var session: GlassPondSession

  var body: some View {
    Canvas { context, size in
      drawNight(in: context, size: size)
      if session.stage == .entrance {
        drawDoor(in: context, size: size)
      } else if session.showsVine {
        drawVine(in: context, size: size)
      } else {
        drawPond(in: context, size: size)
      }
    }
    .overlay(alignment: .topLeading) {
      if session.stage != .entrance {
        progressDots
          .padding(.leading, 20)
          .padding(.top, 18)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Glass Pond scene")
    .accessibilityValue(
      session.stage == .entrance
        ? "A glowing door leads to the Glass Pond."
        : session.showsVine
          ? vineAccessibilityValue
          : session.snapshot.accessibilityDescription
    )
    .accessibilityAddTraits(.updatesFrequently)
  }

  private var vineAccessibilityValue: String {
    if session.stage == .solved { return "Light reaches the moon lily. It is blooming." }
    if session.snapshot.state == .trapped { return "Light reaches the lily." }
    if session.snapshot.state == .skimming { return "Light almost stays in the vine." }
    return "Light escapes at the first bounce."
  }

  private var progressDots: some View {
    HStack(spacing: 5) {
      ForEach(0..<6) { index in
        Capsule()
          .fill(index == session.progressIndex ? PondPalette.pond : .white.opacity(0.27))
          .frame(width: index == session.progressIndex ? 19 : 6, height: 6)
      }
    }
    .accessibilityHidden(true)
  }

  private func drawNight(in context: GraphicsContext, size: CGSize) {
    let bounds = CGRect(origin: .zero, size: size)
    context.fill(
      Path(bounds),
      with: .linearGradient(
        Gradient(colors: [PondPalette.nightBottom, PondPalette.nightTop, PondPalette.violet]),
        startPoint: CGPoint(x: size.width / 2, y: 0),
        endPoint: CGPoint(x: size.width / 2, y: size.height)
      )
    )

    let moon = CGPoint(x: size.width * 0.78, y: size.height * 0.23)
    circle(in: context, at: moon, radius: size.width * 0.105, color: PondPalette.moon.opacity(0.07))
    circle(in: context, at: moon, radius: size.width * 0.072, color: PondPalette.moon.opacity(0.12))
    circle(in: context, at: moon, radius: size.width * 0.043, color: PondPalette.moon)
    circle(in: context, at: CGPoint(x: moon.x - 4, y: moon.y - 5), radius: 1.5, color: PondPalette.violet.opacity(0.15))

    let stars: [(CGFloat, CGFloat, CGFloat)] = [
      (0.08, 0.19, 1.5), (0.13, 0.40, 1), (0.19, 0.13, 1), (0.27, 0.28, 1.2),
      (0.34, 0.10, 1.6), (0.40, 0.36, 1), (0.48, 0.15, 1.1), (0.53, 0.27, 1.5),
      (0.61, 0.07, 1), (0.67, 0.33, 1), (0.73, 0.11, 1), (0.87, 0.37, 1.4),
      (0.92, 0.14, 1), (0.96, 0.29, 1.1)
    ]
    for (x, y, radius) in stars {
      circle(
        in: context,
        at: CGPoint(x: size.width * x, y: size.height * y),
        radius: radius,
        color: .white.opacity(0.7)
      )
    }

    for (x, y) in [(0.10, 0.48), (0.21, 0.41), (0.41, 0.44), (0.67, 0.49), (0.91, 0.45)] {
      let point = CGPoint(x: size.width * x, y: size.height * y)
      circle(in: context, at: point, radius: 10, color: PondPalette.light.opacity(0.12))
      circle(in: context, at: point, radius: 2.5, color: PondPalette.light.opacity(0.92))
    }
  }

  private func drawDoor(in context: GraphicsContext, size: CGSize) {
    let width = min(size.width * 0.56, size.height * 0.46)
    let height = min(size.height * 0.65, width * 1.6)
    let rect = CGRect(
      x: (size.width - width) / 2,
      y: (size.height - height) / 2 + size.height * 0.07,
      width: width,
      height: height
    )
    let door = Path(roundedRect: rect, cornerRadius: 18)
    context.fill(door, with: .color(PondPalette.lilac.opacity(0.33)))
    context.stroke(door, with: .color(PondPalette.lavender.opacity(0.6)), lineWidth: 2)
    let inset = rect.insetBy(dx: 12, dy: 12)
    context.fill(
      Path(roundedRect: inset, cornerRadius: 9),
      with: .linearGradient(
        Gradient(colors: [PondPalette.violet, PondPalette.nightBottom]),
        startPoint: CGPoint(x: inset.midX, y: inset.minY),
        endPoint: CGPoint(x: inset.midX, y: inset.maxY)
      )
    )
    let window = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.36)
    circle(in: context, at: window, radius: width * 0.18, color: PondPalette.pond.opacity(0.18))
    circle(in: context, at: window, radius: width * 0.14, color: PondPalette.nightBottom)
    circle(in: context, at: window, radius: width * 0.025, color: PondPalette.moon)
    circle(in: context, at: CGPoint(x: window.x - width * 0.05, y: window.y + width * 0.07), radius: width * 0.035, color: PondPalette.light)
    var seam = Path()
    seam.move(to: CGPoint(x: rect.midX, y: window.y + width * 0.18))
    seam.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    glowingLine(seam, in: context, intensity: 0.72)
    for x in [-1.0, 1.0] {
      let handle = CGRect(x: rect.midX + width * x * 0.03 - 2, y: rect.maxY - height * 0.30, width: 4, height: 24)
      context.fill(Path(roundedRect: handle, cornerRadius: 2), with: .color(.white.opacity(0.85)))
    }
  }

  private func drawPond(in context: GraphicsContext, size: CGSize) {
    let waterY = size.height * 0.57
    drawWater(in: context, size: size, waterY: waterY)

    let snapshot = session.snapshot
    let source = CGPoint(x: size.width * 0.24, y: size.height * 0.84)
    let rise = source.y - waterY
    let crossing = CGPoint(
      x: min(source.x + rise * tan(snapshot.angle * .pi / 180), size.width * 0.94),
      y: waterY
    )
    var incident = Path()
    incident.move(to: source)
    incident.addLine(to: crossing)
    glowingLine(incident, in: context, intensity: 1)

    let reflectedEnd = CGPoint(
      x: crossing.x + (size.height - waterY) * tan(snapshot.angle * .pi / 180),
      y: size.height
    )
    var reflected = Path()
    reflected.move(to: crossing)
    reflected.addLine(to: reflectedEnd)
    glowingLine(reflected, in: context, intensity: max(0.12, snapshot.reflectedFraction))

    if snapshot.state == .skimming {
      var skim = Path()
      skim.move(to: crossing)
      skim.addLine(to: CGPoint(x: size.width, y: waterY - 2))
      glowingLine(skim, in: context, intensity: 0.75)
    } else if let outgoingAngle = snapshot.outgoingAngle {
      var outgoing = Path()
      outgoing.move(to: crossing)
      outgoing.addLine(to: CGPoint(
        x: crossing.x + waterY * tan(outgoingAngle * .pi / 180),
        y: 0
      ))
      glowingLine(outgoing, in: context, intensity: 1 - snapshot.reflectedFraction)
    }

    circle(in: context, at: crossing, radius: 12, color: PondPalette.light.opacity(0.22))
    circle(in: context, at: crossing, radius: 3.5, color: PondPalette.moon)
    drawLumi(in: context, at: source, scale: max(0.72, min(size.width / 420, 1.3)))
  }

  private func drawVine(in context: GraphicsContext, size: CGSize) {
    let waterY = size.height * 0.68
    drawWater(in: context, size: size, waterY: waterY)
    let vineY = size.height * 0.45
    let startX = size.width * 0.17
    let endX = size.width * 0.86
    let vineHeight = max(28, size.height * 0.085)
    let vineRect = CGRect(x: startX, y: vineY - vineHeight / 2, width: endX - startX, height: vineHeight)
    context.fill(Path(roundedRect: vineRect, cornerRadius: vineHeight / 2), with: .color(PondPalette.lilac.opacity(0.3)))
    context.stroke(Path(roundedRect: vineRect, cornerRadius: vineHeight / 2), with: .color(PondPalette.lavender.opacity(0.55)), lineWidth: 1.5)

    let trapped = session.stage == .solved || session.snapshot.state == .trapped
    let rayEndX = trapped ? endX : startX + (endX - startX) * 0.34
    let rayOpacity = trapped ? 1.0 : max(0.2, session.snapshot.reflectedFraction)
    var vineRay = Path()
    vineRay.move(to: CGPoint(x: startX, y: vineY))
    let segments = trapped ? 7 : 2
    for segment in 1...segments {
      let x = startX + (rayEndX - startX) * CGFloat(segment) / CGFloat(segments)
      let y = vineY + (segment.isMultiple(of: 2) ? vineHeight * 0.26 : -vineHeight * 0.26)
      vineRay.addLine(to: CGPoint(x: x, y: y))
    }
    glowingLine(vineRay, in: context, intensity: rayOpacity)

    if !trapped {
      var leak = Path()
      leak.move(to: CGPoint(x: rayEndX, y: vineY - vineHeight * 0.26))
      leak.addLine(to: CGPoint(x: rayEndX + size.width * 0.12, y: vineY - size.height * 0.16))
      glowingLine(leak, in: context, intensity: 0.85)
    }

    for fraction in [0.25, 0.55, 0.78] {
      let x = startX + (endX - startX) * fraction
      let leaf = CGRect(x: x, y: vineY - vineHeight * 0.75, width: 7, height: 13)
      context.fill(Path(ellipseIn: leaf), with: .color(PondPalette.pond.opacity(0.7)))
    }
    drawLumi(in: context, at: CGPoint(x: startX, y: vineY), scale: 0.94)
    drawLily(in: context, at: CGPoint(x: endX + 10, y: vineY), bloomed: session.stage == .solved)
  }

  private func drawWater(in context: GraphicsContext, size: CGSize, waterY: CGFloat) {
    let shore = CGRect(x: 0, y: waterY - 18, width: size.width, height: 24)
    context.fill(Path(shore), with: .color(PondPalette.nightBottom.opacity(0.76)))
    let water = CGRect(x: 0, y: waterY, width: size.width, height: size.height - waterY)
    context.fill(
      Path(water),
      with: .linearGradient(
        Gradient(colors: [PondPalette.pond.opacity(0.98), Color(red: 0.35, green: 0.72, blue: 0.91), PondPalette.nightBottom]),
        startPoint: CGPoint(x: size.width / 2, y: waterY),
        endPoint: CGPoint(x: size.width / 2, y: size.height)
      )
    )
    var surface = Path()
    surface.move(to: CGPoint(x: 0, y: waterY))
    surface.addLine(to: CGPoint(x: size.width, y: waterY))
    context.stroke(surface, with: .color(PondPalette.pond), lineWidth: 2)
    let bottom = CGRect(x: 0, y: size.height * 0.86, width: size.width, height: size.height * 0.14)
    context.fill(Path(bottom), with: .color(PondPalette.nightBottom.opacity(0.82)))

    for x in [0.09, 0.34, 0.64, 0.9] {
      let crystal = CGRect(x: size.width * x, y: size.height * 0.83, width: 11, height: 24)
      context.fill(Path(roundedRect: crystal, cornerRadius: 3), with: .color(PondPalette.lilac.opacity(0.62)))
    }
    for x in [0.1, 0.84] {
      let pad = CGRect(x: size.width * x, y: waterY - 4, width: size.width * 0.12, height: 7)
      context.fill(Path(ellipseIn: pad), with: .color(Color(red: 0.31, green: 0.68, blue: 0.58)))
    }
  }

  private func drawLumi(in context: GraphicsContext, at point: CGPoint, scale: CGFloat) {
    circle(in: context, at: point, radius: 21 * scale, color: PondPalette.light.opacity(0.11))
    circle(in: context, at: point, radius: 15 * scale, color: PondPalette.light.opacity(0.24))
    circle(in: context, at: point, radius: 10 * scale, color: PondPalette.moon)
    circle(in: context, at: CGPoint(x: point.x - 3 * scale, y: point.y - 1 * scale), radius: 1.2 * scale, color: PondPalette.nightBottom)
    circle(in: context, at: CGPoint(x: point.x + 3 * scale, y: point.y - 1 * scale), radius: 1.2 * scale, color: PondPalette.nightBottom)
    circle(in: context, at: CGPoint(x: point.x, y: point.y + 3 * scale), radius: 1 * scale, color: PondPalette.nightBottom)
  }

  private func drawLily(in context: GraphicsContext, at point: CGPoint, bloomed: Bool) {
    let petals = bloomed ? 7 : 3
    for index in 0..<petals {
      let angle = Double(index) * 2 * Double.pi / Double(petals)
      let distance: CGFloat = bloomed ? 10 : 5
      let center = CGPoint(x: point.x + cos(angle) * distance, y: point.y + sin(angle) * distance)
      let petal = CGRect(x: center.x - 6, y: center.y - 10, width: 12, height: 20)
      context.fill(Path(ellipseIn: petal), with: .color(PondPalette.lavender.opacity(bloomed ? 0.95 : 0.72)))
    }
    circle(in: context, at: point, radius: 5, color: PondPalette.moon)
  }

  private func glowingLine(_ path: Path, in context: GraphicsContext, intensity: Double) {
    let alpha = min(max(intensity, 0), 1)
    context.stroke(path, with: .color(PondPalette.light.opacity(alpha * 0.15)), lineWidth: 14)
    context.stroke(path, with: .color(PondPalette.light.opacity(alpha * 0.35)), lineWidth: 6)
    context.stroke(path, with: .color(PondPalette.moon.opacity(alpha)), lineWidth: 2.5)
  }

  private func circle(in context: GraphicsContext, at center: CGPoint, radius: CGFloat, color: Color) {
    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    context.fill(Path(ellipseIn: rect), with: .color(color))
  }
}
