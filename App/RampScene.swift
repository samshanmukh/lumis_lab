import SwiftUI

/// The marble ramp in Lumi’s moon garden. The hinge sets the ramp’s slope, and a firefly sleeps
/// in a flower at the end of the path while Lumi watches beside it. The stars and fireflies in
/// the sky drift on their own loops and hold still with Reduce Motion.
struct RampScene: View {
  var model: MarbleChapterModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      let layout = RampLayout(size: geometry.size, angle: model.rampDegrees, mass: model.mass)
      ZStack(alignment: .topLeading) {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
          let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
          Canvas { context, _ in
            drawSky(in: &context, layout: layout, time: time)
            drawGarden(in: &context, layout: layout)
            drawRamp(in: &context, layout: layout)
            drawFlower(in: &context, layout: layout, time: time)
            drawBall(in: &context, layout: layout)
          }
        }

        LumiView(mood: lumiMood, radius: layout.lumiRadius)
          .position(layout.lumiCenter)
          .animation(.easeInOut(duration: 0.2), value: lumiMood)

        SceneLabel(text: model.fireflyAwake ? "awake!" : "sleepy firefly", kind: .goal(met: model.fireflyAwake))
          .fixedSize()
          .position(x: layout.targetX, y: layout.labelY)
          .animation(.easeInOut(duration: 0.2), value: model.fireflyAwake)

        if model.fireflyAwake {
          FireflyWakes(perch: layout.perch, scale: layout.scale)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Marble ramp with a firefly target")
    .accessibilityValue(model.fireflyAwake ? "The marble woke the firefly" : model.isRolling ? "Marble rolling" : "Ready to roll")
  }

  /// Lumi watches her marble: dozing until there’s a hinge, wide-eyed while it rolls,
  /// worried when it misses, and happy when the firefly wakes.
  private var lumiMood: LumiMood {
    if model.fireflyAwake { return .happy }
    if model.isRolling { return .wonder }
    if model.hingeDegrees == nil { return .sleepy }
    if model.lastOutcome != nil { return .worried }
    return .calm
  }

  // MARK: Sky

  private func drawSky(in context: inout GraphicsContext, layout: RampLayout, time: TimeInterval) {
    let size = layout.size
    let horizon = layout.floorY
    let scale = layout.scale
    context.fill(
      Path(CGRect(origin: .zero, size: size)),
      with: .linearGradient(
        Gradient(stops: [
          .init(color: LabColor.labelSurface, location: 0),
          .init(color: LabColor.gardenSky, location: 0.6),
          .init(color: LabColor.gardenHorizon, location: 1)
        ]),
        startPoint: .zero,
        endPoint: CGPoint(x: 0, y: horizon)
      )
    )

    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 25 * scale))
      let glow = CGRect(x: -size.width * 0.1, y: horizon - 70 * scale, width: size.width * 1.2, height: 120 * scale)
      layer.fill(Path(ellipseIn: glow), with: .color(LabColor.gardenGlow.opacity(0.22)))
    }

    for index in 0..<34 {
      let x = CGFloat((index * 137 + 47) % 997) / 997 * size.width
      let y = CGFloat((index * 281 + 79) % 991) / 991 * horizon * 0.55
      let diameter: CGFloat = (index % 7 == 0 ? 3.2 : 1.8) * max(0.8, scale)
      let wave = 0.5 + 0.5 * sin(2 * .pi * time / (3 + Double(index % 4)) + Double(index))
      context.fill(
        Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
        with: .color(LabColor.secondaryInk.opacity(0.35 + 0.55 * wave))
      )
    }

    // The top-trailing corner is left clear for the hinge readout.
    let moon = CGPoint(x: size.width * 0.42, y: size.height * 0.16)
    let moonRadius = 19 * scale
    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 18 * scale))
      let halo = moonRadius * 4
      layer.fill(
        Path(ellipseIn: CGRect(x: moon.x - halo, y: moon.y - halo, width: halo * 2, height: halo * 2)),
        with: .color(LabColor.moonGlow.opacity(0.14))
      )
    }
    context.fill(
      Path(ellipseIn: CGRect(x: moon.x - moonRadius, y: moon.y - moonRadius, width: moonRadius * 2, height: moonRadius * 2)),
      with: .radialGradient(
        Gradient(stops: [
          .init(color: LabColor.moonCore, location: 0),
          .init(color: LabColor.moonHalo, location: 0.7),
          .init(color: LabColor.moonRim, location: 1)
        ]),
        center: CGPoint(x: moon.x - 3 * scale, y: moon.y - 3 * scale),
        startRadius: 0,
        endRadius: moonRadius * 1.25
      )
    )

    // Each drift is built from whole harmonics of an 8 s loop, so the path repeats seamlessly.
    let loop = 2 * .pi * time / 8
    for (index, firefly) in Self.skyFireflies.enumerated() {
      let phase = Double(index) * 1.7
      let center = CGPoint(
        x: firefly.x * size.width + 10 * scale * CGFloat(sin(loop + phase)),
        y: firefly.y * horizon + 6 * scale * CGFloat(cos(2 * loop + phase))
      )
      drawFirefly(at: center, radius: firefly.size * scale, lit: true, in: &context)
    }
  }

  // MARK: Garden

  private func drawGarden(in context: inout GraphicsContext, layout: RampLayout) {
    let size = layout.size
    let floor = layout.floorY
    let scale = layout.scale

    var farHills = Path()
    farHills.move(to: CGPoint(x: 0, y: floor))
    farHills.addLine(to: CGPoint(x: 0, y: floor - 46 * scale))
    farHills.addCurve(
      to: CGPoint(x: size.width * 0.5, y: floor - 40 * scale),
      control1: CGPoint(x: size.width * 0.16, y: floor - 64 * scale),
      control2: CGPoint(x: size.width * 0.33, y: floor - 26 * scale)
    )
    farHills.addCurve(
      to: CGPoint(x: size.width, y: floor - 52 * scale),
      control1: CGPoint(x: size.width * 0.66, y: floor - 56 * scale),
      control2: CGPoint(x: size.width * 0.85, y: floor - 30 * scale)
    )
    farHills.addLine(to: CGPoint(x: size.width, y: floor))
    farHills.closeSubpath()
    context.fill(farHills, with: .color(LabColor.gardenFarHills))

    var nearHills = Path()
    nearHills.move(to: CGPoint(x: 0, y: floor))
    nearHills.addLine(to: CGPoint(x: 0, y: floor - 14 * scale))
    nearHills.addCurve(
      to: CGPoint(x: size.width * 0.55, y: floor - 16 * scale),
      control1: CGPoint(x: size.width * 0.18, y: floor - 28 * scale),
      control2: CGPoint(x: size.width * 0.36, y: floor - 4 * scale)
    )
    nearHills.addCurve(
      to: CGPoint(x: size.width, y: floor - 12 * scale),
      control1: CGPoint(x: size.width * 0.72, y: floor - 26 * scale),
      control2: CGPoint(x: size.width * 0.88, y: floor - 8 * scale)
    )
    nearHills.addLine(to: CGPoint(x: size.width, y: floor))
    nearHills.closeSubpath()
    context.fill(nearHills, with: .color(LabColor.gardenNearHills))

    // Hedges line the far end of the path, with glowing blossoms.
    for hedge in Self.hedges {
      let rect = CGRect(
        x: size.width * hedge.x - hedge.width * scale / 2,
        y: floor - hedge.height * scale * 0.72,
        width: hedge.width * scale,
        height: hedge.height * scale
      )
      context.fill(Path(ellipseIn: rect), with: .color(LabColor.hedge))
    }
    for blossom in Self.blossoms {
      let center = CGPoint(x: size.width * blossom.x, y: floor - blossom.lift * scale)
      let radius = 2.4 * scale
      context.drawLayer { layer in
        layer.addFilter(.shadow(color: LabColor.retry.opacity(0.9), radius: 3.5 * scale))
        layer.fill(
          Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
          with: .color(LabColor.lilyGlow)
        )
      }
    }

    context.fill(
      Path(CGRect(x: 0, y: floor, width: size.width, height: max(0, size.height - floor))),
      with: .linearGradient(
        Gradient(colors: [LabColor.pathTop, LabColor.pathBottom]),
        startPoint: CGPoint(x: 0, y: floor),
        endPoint: CGPoint(x: 0, y: size.height)
      )
    )
    context.fill(
      Path(CGRect(x: 0, y: floor - scale, width: size.width, height: 2 * scale)),
      with: .linearGradient(
        Gradient(stops: [
          .init(color: LabColor.pathEdge.opacity(0.15), location: 0),
          .init(color: LabColor.pathEdge.opacity(0.6), location: 0.4),
          .init(color: LabColor.pathEdge.opacity(0.6), location: 0.7),
          .init(color: LabColor.pathEdge.opacity(0.15), location: 1)
        ]),
        startPoint: .zero,
        endPoint: CGPoint(x: size.width, y: 0)
      )
    )

    // Moon grass at both ends of the path.
    for (index, base) in Self.grass.enumerated() {
      let root = CGPoint(x: base * size.width, y: floor)
      let lean: CGFloat = base < 0.5 ? -3 : 3
      let tip = CGPoint(x: root.x + lean * scale, y: floor - CGFloat(22 + index % 3 * 5) * scale)
      var blade = Path()
      blade.move(to: root)
      blade.addQuadCurve(to: tip, control: CGPoint(x: root.x, y: (root.y + tip.y) / 2))
      context.stroke(blade, with: .color(LabColor.rampShade.opacity(0.45)), style: StrokeStyle(lineWidth: 2 * scale, lineCap: .round))
    }
  }

  // MARK: Ramp

  private func drawRamp(in context: inout GraphicsContext, layout: RampLayout) {
    let scale = layout.scale
    let floor = layout.floorY

    for t in [0.18, 0.42, 0.66] {
      let point = layout.curvePoint(t)
      guard floor - point.y > 6 * scale else { continue }
      var leg = Path()
      leg.move(to: point)
      leg.addLine(to: CGPoint(x: point.x, y: floor))
      context.stroke(leg, with: .color(LabColor.rampShade.opacity(0.3)), lineWidth: 1.5 * scale)
    }

    context.drawGardenRamp(layout.rampPath, top: layout.start, floor: floor, scale: scale)

    context.drawLayer { layer in
      layer.addFilter(.shadow(color: LabColor.rampShade.opacity(0.8), radius: 4 * scale))
      let radius = 5 * scale
      layer.fill(
        Path(ellipseIn: CGRect(x: layout.start.x - radius, y: layout.start.y - radius, width: radius * 2, height: radius * 2)),
        with: .color(LabColor.rampRail.opacity(0.9))
      )
    }
  }

  // MARK: The firefly’s flower

  /// The landing ring, and the flower whose firefly sleeps until the marble stops in the ring.
  private func drawFlower(in context: inout GraphicsContext, layout: RampLayout, time: TimeInterval) {
    let scale = layout.scale
    let x = layout.targetX
    let floor = layout.floorY
    let awake = model.fireflyAwake
    let pulse = awake ? 0.5 + 0.5 * sin(time * 4) : 0

    func point(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint {
      CGPoint(x: x + dx * scale, y: floor + dy * scale)
    }

    let ring = Path(ellipseIn: CGRect(x: x - 24 * scale, y: floor - 6 * scale, width: 48 * scale, height: 12 * scale))
    context.fill(ring, with: .color(LabColor.label.opacity(0.12 + 0.14 * pulse)))
    context.stroke(ring, with: .color(LabColor.label.opacity(0.75)), style: StrokeStyle(lineWidth: 1.5 * scale, dash: [3 * scale, 4 * scale]))

    context.fill(
      Path(ellipseIn: CGRect(origin: point(-9, awake ? -52 : -45), size: CGSize(width: 18 * scale, height: 42 * scale))),
      with: .linearGradient(
        Gradient(colors: [LabColor.petal.opacity(awake ? 0.85 : 0.55), LabColor.rampShadeDeep.opacity(0.3)]),
        startPoint: point(0, -45),
        endPoint: point(0, -3)
      )
    )
    for side in [-1.0, 1.0] {
      var petal = context
      let base = point(CGFloat(side) * 12, -14)
      petal.translateBy(x: base.x, y: base.y)
      petal.rotate(by: .degrees(side * (awake ? 55 : 30)))
      petal.fill(
        Path(ellipseIn: CGRect(x: -9 * scale, y: -40 * scale, width: 18 * scale, height: 44 * scale)),
        with: .linearGradient(
          Gradient(colors: [LabColor.petal.opacity(awake ? 0.9 : 0.72), LabColor.rampShadeDeep.opacity(0.45)]),
          startPoint: CGPoint(x: 0, y: -40 * scale),
          endPoint: CGPoint(x: 0, y: 4 * scale)
        )
      )
    }
    context.fill(
      Path(ellipseIn: CGRect(origin: point(-21, -13.5), size: CGSize(width: 42 * scale, height: 15 * scale))),
      with: .linearGradient(
        Gradient(colors: [LabColor.flowerCup, LabColor.pathTop]),
        startPoint: point(0, -13.5),
        endPoint: point(0, 1.5)
      )
    )

    if !awake {
      drawFirefly(at: layout.perch, radius: 18 * scale, lit: false, in: &context)
    }
  }

  private func drawFirefly(at center: CGPoint, radius: CGFloat, lit: Bool, in context: inout GraphicsContext) {
    if lit {
      context.fill(
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
        with: .radialGradient(
          Gradient(colors: [LabColor.label.opacity(0.45), LabColor.label.opacity(0)]),
          center: center,
          startRadius: 0,
          endRadius: radius
        )
      )
    }
    for side in [-1.0, 1.0] {
      var wing = context
      wing.translateBy(x: center.x + CGFloat(side) * radius * 0.22, y: center.y - radius * 0.25)
      wing.rotate(by: .degrees(side * 35))
      wing.fill(
        Path(ellipseIn: CGRect(x: -radius * 0.23, y: -radius * 0.14, width: radius * 0.46, height: radius * 0.28)),
        with: .color(lit ? LabColor.softLight.opacity(0.7) : .white.opacity(0.16))
      )
    }
    let body = radius * 0.34
    context.fill(
      Path(ellipseIn: CGRect(x: center.x - body / 2, y: center.y - body / 2, width: body, height: body)),
      with: .color(lit ? LabColor.label : .white.opacity(0.28))
    )
  }

  // MARK: Marble

  private func drawBall(in context: inout GraphicsContext, layout: RampLayout) {
    let point = model.phase == .flat || model.phase == .stopped
      ? CGPoint(x: layout.end.x + model.displayedFlatDistance * layout.size.width,
                y: layout.floorY - layout.ballRadius)
      : layout.ballOnRamp(model.rampProgress)
    context.drawMarble(at: point, radius: layout.ballRadius, rotation: model.rotation, glowBlur: 5 * layout.scale)
  }

  // MARK: Artwork

  /// Sky fireflies as fractions of the width and of the sky’s height, with a glow radius.
  private static let skyFireflies: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
    (0.16, 0.12, 12), (0.3, 0.34, 14), (0.52, 0.06, 11), (0.66, 0.46, 15), (0.9, 0.62, 12)
  ]

  private static let hedges: [(x: CGFloat, width: CGFloat, height: CGFloat)] = [
    (0.53, 52, 32), (0.6, 68, 38), (0.67, 73, 36), (0.8, 69, 41), (0.87, 66, 42), (0.94, 70, 48), (1.0, 57, 49)
  ]

  private static let blossoms: [(x: CGFloat, lift: CGFloat)] = [
    (0.58, 20), (0.66, 16), (0.86, 18), (0.93, 24)
  ]

  private static let grass: [CGFloat] = [0.015, 0.03, 0.045, 0.06, 0.955, 0.97, 0.985]
}

extension GraphicsContext {
  /// A garden ramp: a soft shade beneath it, a lavender glow, and a bright rail on top.
  func drawGardenRamp(_ rail: Path, top: CGPoint, floor: CGFloat, scale: CGFloat) {
    var shade = rail
    shade.addLine(to: CGPoint(x: top.x, y: floor))
    shade.closeSubpath()
    fill(shade, with: .linearGradient(
      Gradient(colors: [LabColor.rampShade.opacity(0.26), LabColor.rampShadeDeep.opacity(0.05)]),
      startPoint: CGPoint(x: 0, y: top.y),
      endPoint: CGPoint(x: 0, y: floor)
    ))
    drawLayer { layer in
      layer.addFilter(.shadow(color: LabColor.gardenGlow.opacity(0.6), radius: 7 * scale))
      layer.stroke(rail, with: .color(LabColor.rampGlow.opacity(0.5)), style: StrokeStyle(lineWidth: 9 * scale, lineCap: .round))
    }
    stroke(rail, with: .color(LabColor.rampRail.opacity(0.95)), style: StrokeStyle(lineWidth: max(1.5, 2.5 * scale), lineCap: .round))
  }

  /// Lumi’s marble: warm glass with a glow, a swirl that turns as it rolls, and a shine that stays put.
  func drawMarble(at center: CGPoint, radius: CGFloat, rotation: Double, glowBlur: CGFloat) {
    drawLayer { layer in
      layer.addFilter(.blur(radius: glowBlur))
      let glow = radius * 1.8
      layer.fill(
        Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)),
        with: .color(LabColor.amber.opacity(0.24))
      )
    }

    var ball = self
    ball.translateBy(x: center.x, y: center.y)
    ball.fill(
      Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
      with: .radialGradient(
        Gradient(stops: [
          .init(color: LabColor.marbleCore, location: 0),
          .init(color: LabColor.beamGlow, location: 0.6),
          .init(color: LabColor.amber, location: 1)
        ]),
        center: CGPoint(x: radius * 0.08, y: radius * 0.12),
        startRadius: 0,
        endRadius: radius * 1.1
      )
    )
    var swirl = ball
    swirl.rotate(by: .radians(rotation))
    swirl.fill(
      Path(ellipseIn: CGRect(x: radius * 0.18, y: -radius * 0.14, width: radius * 0.44, height: radius * 0.3)),
      with: .color(LabColor.glow.opacity(0.55))
    )
    ball.fill(
      Path(ellipseIn: CGRect(x: -radius * 0.58, y: -radius * 0.62, width: radius * 0.46, height: radius * 0.34)),
      with: .color(.white.opacity(0.85))
    )
  }
}

/// The firefly wakes, lifts off its flower, and a few friends gather round.
private struct FireflyWakes: View {
  var perch: CGPoint
  var scale: CGFloat

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var awake = false

  private static let lift: CGFloat = 84
  private static let gathering: [CGSize] = [
    CGSize(width: -62, height: -18), CGSize(width: -34, height: -64), CGSize(width: 30, height: -58), CGSize(width: 62, height: -12)
  ]
  private static let origins: [CGSize] = [
    CGSize(width: -520, height: -240), CGSize(width: -220, height: -420), CGSize(width: 260, height: -380), CGSize(width: 420, height: -140)
  ]

  var body: some View {
    let lifted = CGPoint(x: perch.x, y: perch.y - Self.lift * scale)
    ZStack(alignment: .topLeading) {
      Color.clear
      FireflyView(lit: true, size: 32 * scale)
        .position(awake ? lifted : perch)
      ForEach(Self.gathering.indices, id: \.self) { index in
        let offset = awake ? Self.gathering[index] : Self.origins[index]
        FireflyView(lit: true, size: 22 * scale)
          .position(x: lifted.x + offset.width * scale, y: lifted.y + offset.height * scale)
          .opacity(awake ? 1 : 0)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .task {
      try? await Task.sleep(for: .milliseconds(150))
      withAnimation(reduceMotion ? LabMotion.reduced : .spring(duration: 1.6, bounce: 0.3)) { awake = true }
    }
  }
}

private struct RampLayout {
  var size: CGSize
  var angle: Double
  var mass: Double

  /// The garden’s artwork is sized for a 475 pt pane and scales from there.
  var scale: CGFloat { min(1.25, max(0.7, min(size.width, size.height) / 475)) }
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

  /// Where the firefly sleeps, in the flower’s bud.
  var perch: CGPoint { CGPoint(x: targetX, y: floorY - 26 * scale) }
  var labelY: CGFloat { floorY - 72 * scale }

  /// Lumi hovers beside her sleeping friend’s flower, above the path, so a marble that rolls
  /// past still shows where it stopped.
  var lumiRadius: CGFloat { max(20, 24 * scale) }
  var lumiCenter: CGPoint {
    CGPoint(
      x: min(targetX + 88 * scale, size.width - lumiRadius * 1.35),
      y: floorY - 84 * scale
    )
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

  func curvePoint(_ fraction: Double) -> CGPoint {
    let t = CGFloat(fraction)
    let inverse = 1 - t
    return CGPoint(
      x: inverse * inverse * inverse * start.x
        + 3 * inverse * inverse * t * control1.x
        + 3 * inverse * t * t * control2.x
        + t * t * t * end.x,
      y: inverse * inverse * inverse * start.y
        + 3 * inverse * inverse * t * control1.y
        + 3 * inverse * t * t * control2.y
        + t * t * t * end.y
    )
  }

  func ballOnRamp(_ fraction: Double) -> CGPoint {
    let t = CGFloat(fraction)
    let inverse = 1 - t
    let point = curvePoint(fraction)
    let dx = 3 * inverse * inverse * (control1.x - start.x)
      + 6 * inverse * t * (control2.x - control1.x)
      + 3 * t * t * (end.x - control2.x)
    let dy = 3 * inverse * inverse * (control1.y - start.y)
      + 6 * inverse * t * (control2.y - control1.y)
      + 3 * t * t * (end.y - control2.y)
    let length = max(1, hypot(dx, dy))
    return CGPoint(x: point.x + ballRadius * dy / length, y: point.y - ballRadius * dx / length)
  }
}
