import SwiftUI

/// The moon garden with the ramp, drawn from the design’s 669 × 476 artwork and fitted to its
/// frame with the path along the bottom. Wider frames stretch the sky, hills and path to the
/// sides; the ramp, flags and flower keep their places.
struct MarbleSceneView: View {
  var scene: MarbleSceneState

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var pulseStart: Date?

  var body: some View {
    GeometryReader { geometry in
      let fit = GardenFit(size: geometry.size)
      ZStack(alignment: .topLeading) {
        TimelineView(.animation(minimumInterval: scene.rolling.isEmpty ? 1.0 / 30 : 1.0 / 60, paused: reduceMotion && scene.rolling.isEmpty)) { timeline in
          let now = timeline.date
          let time = reduceMotion ? 0 : now.timeIntervalSinceReferenceDate
          Canvas { context, size in
            drawSky(fit, time: time, in: &context, size: size)
            drawGround(fit, in: &context, size: size)
            drawFlower(fit, in: &context)
            for ramp in scene.ramps { drawRamp(ramp, fit, in: &context) }
            if scene.showsStarLine { drawStarLine(fit, in: &context) }
            drawCallouts(fit, in: &context)
            drawTrail(fit, in: &context)
            for flag in scene.flags { drawFlag(flag, fit, now: now, in: &context) }
            for center in scene.restingMarbles { drawMarble(at: fit.point(center), fit, in: &context) }
            for marble in scene.rolling {
              let sample = marble.plan.sample(at: now.timeIntervalSince(marble.startedAt))
              drawMarble(at: fit.point(sample.center), fit, in: &context)
            }
          }
        }

        LumiView(mood: scene.lumiMood, radius: 21 * fit.scale)
          .position(fit.point(CGPoint(x: 58, y: 214)))
          .animation(.easeInOut(duration: 0.2), value: scene.lumiMood)

        if scene.flowerOpen {
          FlowerWakes(fit: fit, gathers: scene.firefliesGather)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
    }
    .allowsHitTesting(false)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Ramp")
    .accessibilityValue(scene.accessibilityValue)
    .onChange(of: scene.labelPulse) { pulseStart = .now }
  }

  // MARK: Garden

  private func drawSky(_ fit: GardenFit, time: TimeInterval, in context: inout GraphicsContext, size: CGSize) {
    let skyBottom = fit.y(420)
    context.fill(
      Path(CGRect(x: 0, y: 0, width: size.width, height: skyBottom)),
      with: .linearGradient(
        Gradient(stops: [
          .init(color: LabColor.labelSurface, location: 0),
          .init(color: LabColor.gardenSky, location: max(0.02, min(0.98, fit.y(260) / max(1, skyBottom)))),
          .init(color: LabColor.gardenHorizon, location: 1)
        ]),
        startPoint: .zero,
        endPoint: CGPoint(x: 0, y: skyBottom)
      )
    )

    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 25 * fit.scale))
      let glow = CGRect(x: size.width / 2 - 420 * fit.stretch, y: fit.y(328), width: 840 * fit.stretch, height: 180 * fit.scale)
      layer.fill(Path(ellipseIn: glow), with: .color(LabColor.gardenGlow.opacity(0.22)))
    }

    for index in 0..<34 {
      let x = CGFloat((index * 137 + 47) % 997) / 997 * size.width
      let y = CGFloat((index * 281 + 79) % 991) / 991 * fit.y(200)
      let diameter: CGFloat = (index % 7 == 0 ? 3.4 : 2) * max(0.7, fit.scale)
      let wave = 0.5 + 0.5 * sin(2 * .pi * time / (3 + Double(index % 4)) + Double(index))
      context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)), with: .color(.white.opacity(0.35 + 0.5 * wave)))
    }

    let moon = fit.point(CGPoint(x: 566, y: 72))
    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 18 * fit.scale))
      layer.fill(Path(ellipseIn: CGRect(x: moon.x - 80 * fit.scale, y: moon.y - 80 * fit.scale, width: 160 * fit.scale, height: 160 * fit.scale)), with: .color(LabColor.moonGlow.opacity(0.12)))
    }
    let moonRadius = 20 * fit.scale
    context.fill(
      Path(ellipseIn: CGRect(x: moon.x - moonRadius, y: moon.y - moonRadius, width: moonRadius * 2, height: moonRadius * 2)),
      with: .radialGradient(
        Gradient(stops: [
          .init(color: LabColor.moonCore, location: 0),
          .init(color: Color(hex: 0xFFF1CF), location: 0.7),
          .init(color: LabColor.moonRim, location: 1)
        ]),
        center: CGPoint(x: moon.x - 3 * fit.scale, y: moon.y - 3 * fit.scale),
        startRadius: 0,
        endRadius: 25 * fit.scale
      )
    )

    // Sky fireflies drift on 8 s loops.
    let loop = 2 * .pi * time / 8
    let fireflies: [(CGPoint, CGFloat)] = [
      (CGPoint(x: 92, y: 120), 14), (CGPoint(x: 210, y: 64), 12), (CGPoint(x: 420, y: 168), 16),
      (CGPoint(x: 476, y: 96), 12), (CGPoint(x: 636, y: 206), 14)
    ]
    for (index, firefly) in fireflies.enumerated() {
      let phase = Double(index) * 1.7
      let drift = CGPoint(x: firefly.0.x + 10 * sin(loop + phase), y: firefly.0.y + 6 * cos(loop * 2 + phase))
      drawFirefly(at: fit.point(drift), radius: firefly.1 * fit.scale, lit: true, in: &context)
    }
  }

  private func drawGround(_ fit: GardenFit, in context: inout GraphicsContext, size: CGSize) {
    context.fill(hills(fit, offset: 313.33, points: Self.farHills), with: .color(LabColor.gardenFarHills))
    context.fill(hills(fit, offset: 358.21, points: Self.nearHills), with: .color(LabColor.gardenNearHills))

    for hedge in Self.hedges {
      context.fill(Path(ellipseIn: fit.rect(hedge)), with: .color(LabColor.hedge))
    }
    for flower in Self.hedgeFlowers {
      let center = fit.point(flower)
      context.drawLayer { layer in
        layer.addFilter(.shadow(color: Color(hex: 0xB8A4FF).opacity(0.9), radius: 3.5 * fit.scale))
        layer.fill(Path(ellipseIn: CGRect(x: center.x - 2.4 * fit.scale, y: center.y - 2.4 * fit.scale, width: 4.8 * fit.scale, height: 4.8 * fit.scale)), with: .color(Color(hex: 0xFFB0DA)))
      }
    }

    let pathTop = fit.y(418)
    context.fill(
      Path(CGRect(x: 0, y: pathTop, width: size.width, height: max(0, size.height - pathTop))),
      with: .linearGradient(Gradient(colors: [LabColor.pathTop, LabColor.pathBottom]), startPoint: CGPoint(x: 0, y: pathTop), endPoint: CGPoint(x: 0, y: size.height))
    )
    context.fill(
      Path(CGRect(x: 0, y: fit.y(417), width: size.width, height: 2 * fit.scale)),
      with: .linearGradient(
        Gradient(stops: [
          .init(color: LabColor.pathEdge.opacity(0.15), location: 0),
          .init(color: LabColor.pathEdge.opacity(0.6), location: 0.4),
          .init(color: LabColor.pathEdge.opacity(0.6), location: 0.7),
          .init(color: LabColor.pathEdge.opacity(0.15), location: 1)
        ]),
        startPoint: CGPoint(x: 0, y: 0),
        endPoint: CGPoint(x: size.width, y: 0)
      )
    )
    for index in 0..<6 {
      let stone = fit.rect(CGRect(x: 370 + CGFloat(index) * 46, y: 430.4, width: 32, height: 7.2))
      context.fill(Path(ellipseIn: stone), with: .color(LabColor.rampShade.opacity(0.13)))
      context.stroke(Path(ellipseIn: stone.insetBy(dx: 0.5, dy: 0.5)), with: .color(Color(hex: 0xE6DCFF).opacity(0.16)), lineWidth: 1)
    }
    for base in [CGFloat(10), 16, 22, 28, 646, 652, 658, 663] {
      var blade = Path()
      let root = fit.point(CGPoint(x: base, y: 418))
      let tip = fit.point(CGPoint(x: base + (base < 300 ? -3 : 3), y: 392 - CGFloat(Int(base) % 3) * 4))
      blade.move(to: root)
      blade.addQuadCurve(to: tip, control: CGPoint(x: root.x, y: (root.y + tip.y) / 2))
      context.stroke(blade, with: .color(LabColor.rampShade.opacity(0.45)), style: StrokeStyle(lineWidth: 2 * fit.scale, lineCap: .round))
    }
  }

  private func hills(_ fit: GardenFit, offset: CGFloat, points: [(CGPoint, CGPoint, CGPoint)]) -> Path {
    var path = Path()
    let bottom = fit.y(418)
    path.move(to: CGPoint(x: 0, y: bottom))
    guard let first = points.first else { return path }
    path.addLine(to: CGPoint(x: 0, y: fit.y(offset + first.2.y)))
    for (index, segment) in points.enumerated() where index > 0 {
      path.addCurve(
        to: CGPoint(x: fit.stretchX(segment.2.x), y: fit.y(offset + segment.2.y)),
        control1: CGPoint(x: fit.stretchX(segment.0.x), y: fit.y(offset + segment.0.y)),
        control2: CGPoint(x: fit.stretchX(segment.1.x), y: fit.y(offset + segment.1.y))
      )
    }
    path.addLine(to: CGPoint(x: fit.stretchX(669), y: bottom))
    path.closeSubpath()
    return path
  }

  // MARK: Flower

  private func drawFlower(_ fit: GardenFit, in context: inout GraphicsContext) {
    let open = scene.flowerOpen
    context.fill(
      Path(ellipseIn: fit.rect(CGRect(x: 603, y: open ? 366 : 373, width: 18, height: 42))),
      with: .linearGradient(Gradient(colors: [Color(hex: 0xF3EDFF).opacity(open ? 0.8 : 0.55), LabColor.rampShadeDeep.opacity(0.3)]), startPoint: fit.point(CGPoint(x: 612, y: 373)), endPoint: fit.point(CGPoint(x: 612, y: 415)))
    )
    for side in [-1.0, 1.0] {
      var petal = context
      let base = fit.point(CGPoint(x: 612 + side * 12, y: 404))
      petal.translateBy(x: base.x, y: base.y)
      petal.rotate(by: .degrees(side * (open ? 55 : 30)))
      petal.fill(
        Path(ellipseIn: CGRect(x: -9 * fit.scale, y: -40 * fit.scale, width: 18 * fit.scale, height: 44 * fit.scale)),
        with: .linearGradient(Gradient(colors: [LabColor.petal.opacity(open ? 0.9 : 0.72), LabColor.rampShadeDeep.opacity(0.45)]), startPoint: CGPoint(x: 0, y: -40 * fit.scale), endPoint: CGPoint(x: 0, y: 4 * fit.scale))
      )
    }
    context.fill(
      Path(ellipseIn: fit.rect(CGRect(x: 591, y: 404.5, width: 42, height: 15))),
      with: .linearGradient(Gradient(colors: [LabColor.flowerCup, Color(hex: 0x7363CD)]), startPoint: fit.point(CGPoint(x: 612, y: 404.5)), endPoint: fit.point(CGPoint(x: 612, y: 419.5)))
    )
    if !open {
      drawFirefly(at: fit.point(CGPoint(x: 612, y: 392)), radius: 18 * fit.scale, lit: false, in: &context)
    }
  }

  private func drawFirefly(at center: CGPoint, radius: CGFloat, lit: Bool, in context: inout GraphicsContext) {
    if lit {
      context.fill(
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
        with: .radialGradient(Gradient(colors: [LabColor.label.opacity(0.45), LabColor.label.opacity(0)]), center: center, startRadius: 0, endRadius: radius)
      )
    }
    for side in [-1.0, 1.0] {
      var wing = context
      wing.translateBy(x: center.x + side * radius * 0.22, y: center.y - radius * 0.25)
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

  // MARK: Ramp

  private func drawRamp(_ ramp: RampMark, _ fit: GardenFit, in context: inout GraphicsContext) {
    let track = ramp.track
    let alpha = ramp.isGhost ? 0.38 : 1.0
    let top = fit.point(track.top)

    var area = Path()
    area.move(to: top)
    area.addLine(to: fit.point(track.curveStart))
    area.addQuadCurve(to: fit.point(track.curveEnd), control: fit.point(MarbleGarden.foot))
    area.addLine(to: CGPoint(x: top.x, y: fit.y(MarbleGarden.groundY)))
    area.closeSubpath()
    context.fill(area, with: .linearGradient(
      Gradient(colors: [LabColor.rampShade.opacity(0.26 * alpha), LabColor.rampShadeDeep.opacity(0.05 * alpha)]),
      startPoint: CGPoint(x: 0, y: top.y),
      endPoint: CGPoint(x: 0, y: fit.y(MarbleGarden.groundY))
    ))

    for distance in [CGFloat(304), 208, 112] {
      let point = fit.point(track.pointOnRamp(distance))
      var leg = Path()
      leg.move(to: point)
      leg.addLine(to: CGPoint(x: point.x, y: fit.y(MarbleGarden.groundY)))
      context.stroke(leg, with: .color(LabColor.rampShade.opacity(0.3 * alpha)), lineWidth: 1.5 * fit.scale)
    }

    var line = Path()
    line.move(to: top)
    line.addLine(to: fit.point(track.curveStart))
    line.addQuadCurve(to: fit.point(track.curveEnd), control: fit.point(MarbleGarden.foot))
    if !ramp.isGhost {
      context.drawLayer { layer in
        layer.addFilter(.shadow(color: LabColor.gardenGlow.opacity(0.6), radius: 7 * fit.scale))
        layer.stroke(line, with: .color(LabColor.rampGlow.opacity(0.5)), style: StrokeStyle(lineWidth: 9 * fit.scale, lineCap: .round, lineJoin: .round))
      }
    }
    context.stroke(line, with: .color(LabColor.rampRail.opacity(0.95 * alpha)), style: StrokeStyle(lineWidth: max(1.5, 2.5 * fit.scale), lineCap: .round, lineJoin: .round))

    context.drawLayer { layer in
      if !ramp.isGhost { layer.addFilter(.shadow(color: LabColor.rampShade.opacity(0.8), radius: 4 * fit.scale)) }
      layer.fill(Path(ellipseIn: CGRect(x: top.x - 5 * fit.scale, y: top.y - 5 * fit.scale, width: 10 * fit.scale, height: 10 * fit.scale)), with: .color(LabColor.rampRail.opacity(0.9 * alpha)))
    }
  }

  private func drawStarLine(_ fit: GardenFit, in context: inout GraphicsContext) {
    let y = MarbleGarden.groundY - MarbleGarden.starHeight
    var line = Path()
    line.move(to: fit.point(CGPoint(x: 30, y: y)))
    line.addLine(to: fit.point(CGPoint(x: 410, y: y)))
    context.stroke(line, with: .color(Color(hex: 0xFFE3A6).opacity(0.55)), style: StrokeStyle(lineWidth: 1.5 * fit.scale, lineCap: .round, dash: [5 * fit.scale, 7 * fit.scale]))

    let center = fit.point(CGPoint(x: 16, y: y))
    let arm = 7 * fit.scale
    var star = Path()
    star.move(to: CGPoint(x: center.x, y: center.y - arm))
    star.addQuadCurve(to: CGPoint(x: center.x + arm, y: center.y), control: CGPoint(x: center.x + arm * 0.14, y: center.y - arm * 0.14))
    star.addQuadCurve(to: CGPoint(x: center.x, y: center.y + arm), control: CGPoint(x: center.x + arm * 0.14, y: center.y + arm * 0.14))
    star.addQuadCurve(to: CGPoint(x: center.x - arm, y: center.y), control: CGPoint(x: center.x - arm * 0.14, y: center.y + arm * 0.14))
    star.addQuadCurve(to: CGPoint(x: center.x, y: center.y - arm), control: CGPoint(x: center.x - arm * 0.14, y: center.y - arm * 0.14))
    context.drawLayer { layer in
      layer.addFilter(.shadow(color: LabColor.label.opacity(0.8), radius: 3 * fit.scale))
      layer.fill(star, with: .color(Color(hex: 0xFFE3A6)))
    }
  }

  // MARK: Why beats

  private func drawCallouts(_ fit: GardenFit, in context: inout GraphicsContext) {
    guard scene.callouts != .none, scene.ramps.count >= 2 else { return }
    let gentle = scene.ramps[0].track, steep = scene.ramps[1].track
    let starY = MarbleGarden.groundY - MarbleGarden.starHeight
    let gentleX = gentle.pointOnRamp(gentle.startDistance).x
    let steepX = steep.pointOnRamp(steep.startDistance).x

    switch scene.callouts {
    case .sameHeight, .sameDrop:
      for x in [gentleX, steepX] {
        drawArrow(from: fit.point(CGPoint(x: x, y: starY + 4)), to: fit.point(CGPoint(x: x, y: MarbleGarden.groundY - 4)), fit, dashed: true, in: &context)
      }
      drawPill(scene.callouts == .sameHeight ? "same height" : "same drop", at: fit.point(CGPoint(x: (gentleX + steepX) / 2, y: 385)), fit, in: &context)
      if scene.callouts == .sameDrop { drawSameSpeed(fit, in: &context) }
    case .quickSlow:
      let steepMid = steep.pointOnRamp(210)
      drawPill("steep: quick", at: fit.point(CGPoint(x: steepMid.x + 58, y: steepMid.y)), fit, in: &context)
      let gentleMid = gentle.pointOnRamp(220)
      drawPill("gentle: slow", at: fit.point(CGPoint(x: gentleMid.x, y: gentleMid.y + 30)), fit, in: &context)
      drawSameSpeed(fit, in: &context)
    case .startHeights:
      for (track, label) in [(gentle, "starts lower"), (steep, "starts higher")] {
        let start = track.pointOnRamp(track.startDistance)
        drawArrow(from: fit.point(CGPoint(x: start.x, y: start.y + 6)), to: fit.point(CGPoint(x: start.x, y: MarbleGarden.groundY - 4)), fit, dashed: true, in: &context)
        drawPill(label, at: fit.point(CGPoint(x: start.x + 10, y: start.y - 40)), fit, in: &context)
      }
    case .none:
      break
    }
  }

  private func drawSameSpeed(_ fit: GardenFit, in context: inout GraphicsContext) {
    drawPill("same speed", at: fit.point(CGPoint(x: 448, y: 364)), fit, in: &context)
    drawArrow(from: fit.point(CGPoint(x: 400, y: 383)), to: fit.point(CGPoint(x: 480, y: 383)), fit, dashed: false, in: &context)
  }

  private func drawArrow(from start: CGPoint, to end: CGPoint, _ fit: GardenFit, dashed: Bool, in context: inout GraphicsContext) {
    var line = Path()
    line.move(to: start)
    line.addLine(to: end)
    let style = StrokeStyle(lineWidth: 1.8 * fit.scale, lineCap: .round, dash: dashed ? [4 * fit.scale, 4 * fit.scale] : [])
    context.stroke(line, with: .color(LabColor.label.opacity(0.9)), style: style)
    let heading = atan2(end.y - start.y, end.x - start.x)
    let size = 7 * fit.scale
    var head = Path()
    head.move(to: CGPoint(x: end.x - size * cos(heading - 0.55), y: end.y - size * sin(heading - 0.55)))
    head.addLine(to: end)
    head.addLine(to: CGPoint(x: end.x - size * cos(heading + 0.55), y: end.y - size * sin(heading + 0.55)))
    context.stroke(head, with: .color(LabColor.label.opacity(0.9)), style: StrokeStyle(lineWidth: 1.8 * fit.scale, lineCap: .round, lineJoin: .round))
  }

  private func drawPill(_ text: String, at center: CGPoint, _ fit: GardenFit, glowing: Bool = true, in context: inout GraphicsContext) {
    let resolved = context.resolve(
      Text(text)
        .font(.system(size: 12 * max(0.8, fit.scale), weight: .semibold, design: .rounded))
        .foregroundStyle(LabColor.label)
    )
    let textSize = resolved.measure(in: CGSize(width: 300, height: 40))
    let pill = CGRect(x: center.x - textSize.width / 2 - 10, y: center.y - textSize.height / 2 - 4, width: textSize.width + 20, height: textSize.height + 8)
    let shape = Path(roundedRect: pill, cornerRadius: pill.height / 2)
    context.fill(shape, with: .color(LabColor.labelSurface.opacity(0.85)))
    context.stroke(shape, with: .color(LabColor.label.opacity(glowing ? 0.55 : 0.3)), lineWidth: 1)
    context.draw(resolved, at: center)
  }

  // MARK: Rolls

  private func drawTrail(_ fit: GardenFit, in context: inout GraphicsContext) {
    let count = scene.trail.count
    for (index, dot) in scene.trail.enumerated() {
      let point = fit.point(dot)
      let radius = 2.3 * fit.scale
      let alpha = 0.12 + 0.4 * Double(index) / Double(max(1, count - 1))
      context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(Color(hex: 0xFFD68A).opacity(alpha)))
    }
  }

  private func drawFlag(_ flag: FlagMark, _ fit: GardenFit, now: Date, in context: inout GraphicsContext) {
    let age = now.timeIntervalSince(flag.landedAt)
    // The flag drops in with a spring.
    let drop = age < 0.8 && !reduceMotion ? -26 * exp(-age * 7) * cos(age * 16) : 0
    let poleTop = fit.point(CGPoint(x: flag.x, y: 372 + drop))
    let poleBottom = fit.point(CGPoint(x: flag.x, y: MarbleGarden.groundY))
    var pole = Path()
    pole.move(to: poleTop)
    pole.addLine(to: poleBottom)
    context.stroke(pole, with: .color(LabColor.softLight.opacity(0.85)), lineWidth: 1.5 * fit.scale)

    var pennant = Path()
    pennant.move(to: poleTop)
    pennant.addLine(to: fit.point(CGPoint(x: flag.x + 18, y: 378 + drop)))
    pennant.addLine(to: fit.point(CGPoint(x: flag.x, y: 384 + drop)))
    pennant.closeSubpath()
    context.drawLayer { layer in
      layer.addFilter(.shadow(color: LabColor.label.opacity(0.5), radius: 3 * fit.scale))
      layer.fill(pennant, with: .color(LabColor.label))
    }

    let pulsing = pulseStart.map { now.timeIntervalSince($0) < 1.2 } ?? false
    let fresh = flag.isNewest && age < 1.5
    for (index, label) in flag.labels.enumerated() {
      let row = CGFloat(flag.labels.count - 1 - index)
      let center = fit.point(CGPoint(x: flag.x + 9, y: 357 - row * 24 + drop))
      let resolved = context.resolve(
        Text(label)
          .font(.system(size: 12 * max(0.8, fit.scale), weight: .semibold, design: .rounded))
          .foregroundStyle(LabColor.primaryInk)
      )
      let textSize = resolved.measure(in: CGSize(width: 100, height: 40))
      let pill = CGRect(x: center.x - textSize.width / 2 - 8, y: center.y - textSize.height / 2 - 3, width: textSize.width + 16, height: textSize.height + 6)
      let shape = Path(roundedRect: pill, cornerRadius: pill.height / 2)
      let glow = pulsing ? 0.5 + 0.5 * sin(now.timeIntervalSince(pulseStart ?? now) * 10) : (fresh ? 1 - age / 1.5 : 0)
      context.drawLayer { layer in
        if glow > 0 { layer.addFilter(.shadow(color: LabColor.label.opacity(0.8 * glow), radius: 6)) }
        layer.fill(shape, with: .color(LabColor.labelSurface.opacity(0.78)))
      }
      context.stroke(shape, with: .color(glow > 0.05 ? LabColor.label.opacity(0.4 + 0.5 * glow) : .white.opacity(0.22)), lineWidth: 1)
      context.draw(resolved, at: center)
    }
  }

  private func drawMarble(at center: CGPoint, _ fit: GardenFit, in context: inout GraphicsContext) {
    // The artwork is drawn for the standard marble; a bigger or smaller one scales all of it.
    let size = scene.marbleRadius / MarbleGarden.marbleRadius * fit.scale
    let radius = MarbleGarden.marbleRadius * size
    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 5 * size))
      let glow = 28 * size
      layer.fill(Path(ellipseIn: CGRect(x: center.x - glow, y: center.y - glow, width: glow * 2, height: glow * 2)), with: .color(LabColor.amber.opacity(0.34)))
    }
    context.fill(
      Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
      with: .radialGradient(
        Gradient(stops: [
          .init(color: LabColor.marbleCore, location: 0),
          .init(color: Color(hex: 0xFFD68A), location: 0.6),
          .init(color: LabColor.amber, location: 1)
        ]),
        center: CGPoint(x: center.x + 1.2 * size, y: center.y + 1.8 * size),
        startRadius: 0,
        endRadius: 15 * size
      )
    )
    context.fill(
      Path(ellipseIn: CGRect(x: center.x - 7 * size, y: center.y - 7 * size, width: 6.4 * size, height: 4.8 * size)),
      with: .color(.white.opacity(0.85))
    )
  }

  // MARK: Artwork

  private static let farHills: [(CGPoint, CGPoint, CGPoint)] = [
    (.zero, .zero, CGPoint(x: 0, y: 18.67)),
    (CGPoint(x: 80, y: 0.67), CGPoint(x: 160, y: 14.67), CGPoint(x: 250, y: 6.67)),
    (CGPoint(x: 340, y: -1.33), CGPoint(x: 420, y: 20.67), CGPoint(x: 510, y: 10.67)),
    (CGPoint(x: 580, y: 2.67), CGPoint(x: 630, y: -5.33), CGPoint(x: 669, y: 4.67))
  ]

  private static let nearHills: [(CGPoint, CGPoint, CGPoint)] = [
    (.zero, .zero, CGPoint(x: 0, y: 3.79)),
    (CGPoint(x: 100, y: -6.21), CGPoint(x: 180, y: 9.79), CGPoint(x: 280, y: 3.79)),
    (CGPoint(x: 380, y: -4.21), CGPoint(x: 470, y: 13.79), CGPoint(x: 560, y: 3.79)),
    (CGPoint(x: 620, y: -2.21), CGPoint(x: 650, y: -0.21), CGPoint(x: 669, y: 3.79))
  ]

  private static let hedges: [CGRect] = [
    CGRect(x: 344, y: 397.8, width: 52, height: 32.4), CGRect(x: 382.2, y: 395, width: 67.6, height: 37.9),
    CGRect(x: 425.4, y: 396.3, width: 73.2, height: 35.5), CGRect(x: 473.3, y: 393.4, width: 69.4, height: 41.2),
    CGRect(x: 521.1, y: 392.9, width: 65.8, height: 42.2), CGRect(x: 565.2, y: 389.8, width: 69.6, height: 48.3),
    CGRect(x: 618.5, y: 392.3, width: 54.9, height: 43.4), CGRect(x: 663.7, y: 389.6, width: 56.6, height: 48.8)
  ]

  private static let hedgeFlowers: [CGPoint] = [
    CGPoint(x: 412.3, y: 400.3), CGPoint(x: 461.9, y: 405.1), CGPoint(x: 601.2, y: 405.4), CGPoint(x: 640, y: 401.9)
  ]
}

/// Maps the garden’s design coordinates into a frame: the artwork keeps its proportions and sits
/// on the bottom edge, while full-width layers stretch across.
struct GardenFit {
  var size: CGSize
  var scale: CGFloat
  var origin: CGPoint

  init(size: CGSize) {
    self.size = size
    scale = max(0.01, min(size.width / MarbleGarden.size.width, size.height / MarbleGarden.size.height))
    origin = CGPoint(
      x: (size.width - MarbleGarden.size.width * scale) / 2,
      y: size.height - MarbleGarden.size.height * scale
    )
  }

  /// How much wider than the artwork the frame is, for layers that span it.
  var stretch: CGFloat { size.width / MarbleGarden.size.width }

  func point(_ point: CGPoint) -> CGPoint {
    CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
  }

  func y(_ y: CGFloat) -> CGFloat { origin.y + y * scale }

  func stretchX(_ x: CGFloat) -> CGFloat { x * stretch }

  func rect(_ rect: CGRect) -> CGRect {
    CGRect(origin: point(rect.origin), size: CGSize(width: rect.width * scale, height: rect.height * scale))
  }
}

/// Solved: the firefly in the flower wakes and lifts off, and the others gather round.
private struct FlowerWakes: View {
  var fit: GardenFit
  /// The others gather round; once they stop, they drift off again.
  var gathers = true

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var awake = false

  private let gathering: [CGPoint] = [
    CGPoint(x: -70, y: -58), CGPoint(x: -34, y: -96), CGPoint(x: 18, y: -122), CGPoint(x: -112, y: -26), CGPoint(x: 30, y: -66)
  ]
  private let origins: [CGPoint] = [
    CGPoint(x: -700, y: -300), CGPoint(x: -400, y: -500), CGPoint(x: 200, y: -500), CGPoint(x: -700, y: 0), CGPoint(x: 300, y: -200)
  ]

  var body: some View {
    let flower = CGPoint(x: 612, y: 392)
    ZStack(alignment: .topLeading) {
      Color.clear
      FireflyView(lit: true, size: 30 * fit.scale)
        .position(fit.point(CGPoint(x: flower.x, y: flower.y - (awake ? 56 : 0))))
      ForEach(gathering.indices, id: \.self) { index in
        let target = awake && gathers ? gathering[index] : origins[index]
        FireflyView(lit: true, size: 22 * fit.scale)
          .position(fit.point(CGPoint(x: flower.x + target.x, y: flower.y + target.y)))
          .opacity(awake && gathers ? 1 : 0)
      }
      .animation(reduceMotion ? LabMotion.reduced : .easeIn(duration: 1.2), value: gathers)
    }
    .task {
      try? await Task.sleep(for: .milliseconds(150))
      withAnimation(reduceMotion ? LabMotion.reduced : .spring(duration: 1.6, bounce: 0.3)) { awake = true }
    }
  }
}

private extension Color {
  init(hex: UInt32) {
    self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
  }
}
