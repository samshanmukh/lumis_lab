import SwiftUI

/// Everything the Glass Pond scene shows besides the tilt itself.
struct PondSceneStyle: Equatable {
  var mood: LumiMood = .wonder
  /// Checkpoint 2, the challenge and solved: Lumi sits in the crystal vine above the pond.
  var showsVine = false
  /// Why beats 0–2 draw the straight-up line, the labels and the 42° tipping line.
  var whyBeat: Int?
  /// The moon lily opening, 0 to 1.
  var bloom: Double = 0
  /// The challenge’s near miss: the bud glows brighter.
  var almost = false
  /// Solved: the vine fills with light.
  var won = false
  /// Hint level 2 marks the place in the scene where it matters.
  var marksScene = false
  /// Laptop pose: the fold line sits on the water’s surface.
  var showsFold = false
}

/// Maps the design’s 669-wide laptop frame (surface at 475, pond floor band 145 deep) onto
/// any container: the sky scales to the space above the surface, the pond to the band below.
struct PondMap: Equatable {
  var size: CGSize
  var surfaceY: CGFloat
  var depth: CGFloat

  var sx: CGFloat { size.width / 669 }
  var up: CGFloat { max(0.01, surfaceY / 475) }
  var down: CGFloat { max(0.01, depth / 145) }
  /// Uniform scales that keep round things round. The moon, reeds and fireflies keep most of
  /// their size even when the sky is short, as it is with the whole scene in the upper half.
  var skyScale: CGFloat { min(sx, up) }
  var ornamentScale: CGFloat { min(sx, max(up, 0.75)) }
  var pondScale: CGFloat { min(sx, down) }

  func x(_ design: CGFloat) -> CGFloat { design * sx }
  func y(_ design: CGFloat) -> CGFloat {
    design <= 475 ? surfaceY - (475 - design) * up : surfaceY + (design - 475) * down
  }
  func point(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: x(dx), y: y(dy)) }

  var lumiCenter: CGPoint { point(150, 579.4) }
  var floorY: CGFloat { y(601) }

  // The crystal vine: a glass tube in the air, Lumi at its left end, the lily at its tip.
  var vineScale: CGFloat { skyScale }
  var vineCenterY: CGFloat { y(387) }
  var vineRect: CGRect {
    CGRect(x: x(56), y: vineCenterY - 28 * vineScale, width: x(540) - x(56), height: 56 * vineScale)
  }
  var vineHalfBore: CGFloat { 23 * vineScale }
  var vineLumi: CGPoint { CGPoint(x: x(96), y: vineCenterY) }
  var vineTipX: CGFloat { x(524) }
  var lilyHeart: CGPoint { CGPoint(x: x(578), y: vineCenterY + 0.5 * vineScale) }
}

/// The Glass Pond scene. Animatable on the tilt, so hinge smoothing and sweeps redraw the light.
struct PondSceneView: View, Animatable {
  var tilt: Double
  var surfaceY: CGFloat
  var depth: CGFloat
  var style: PondSceneStyle
  var flarePulse = 0

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var flareBoost = 0.0

  var animatableData: Double {
    get { tilt }
    set { tilt = newValue }
  }

  var body: some View {
    GeometryReader { proxy in
      let map = PondMap(size: proxy.size, surfaceY: surfaceY, depth: depth)
      let light = PondLightPath(tilt: tilt, map: map, inVine: style.showsVine)

      ZStack(alignment: .topLeading) {
        PondBackdrop(map: map, showsVine: style.showsVine, showsFold: style.showsFold)
          .equatable()
        PondAmbience(map: map, showsVine: style.showsVine)

        Canvas { context, _ in
          light.draw(in: &context, won: style.won)
        }

        flare(at: light.flarePoint, scale: style.showsVine ? map.vineScale : map.pondScale)

        if style.showsVine {
          MoonLily(bloom: style.bloom, almost: style.almost, scale: map.vineScale)
            .position(map.lilyHeart)
        }

        LumiView(mood: style.mood, radius: lumiRadius(map))
          .position(style.showsVine ? map.vineLumi : map.lumiCenter)
          .animation(.easeInOut(duration: 0.2), value: style.mood)

        if let beat = style.whyBeat, !style.showsVine {
          WhyMarks(beat: beat, exit: light.exitPoint, map: map)
            .id(beat)
            .transition(.opacity.animation(.easeInOut(duration: 0.4)))
        }

        if style.marksScene {
          HintMark(map: map, inVine: style.showsVine, exit: light.exitPoint)
            .transition(.opacity)
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
      .animation(.easeInOut(duration: 0.3), value: style.marksScene)
    }
    .allowsHitTesting(false)
    .onChange(of: flarePulse) {
      guard !reduceMotion else { return }
      flareBoost = 1
      withAnimation(.easeOut(duration: 0.25)) { flareBoost = 0 }
    }
  }

  private func lumiRadius(_ map: PondMap) -> CGFloat {
    style.showsVine ? 102 / 2.7 * map.vineScale : 100 / 2.7 * map.pondScale
  }

  /// Where the beam meets the surface (or the vine wall): a warm glow and a bright core.
  /// Crossing 41.8° pulses it for 0.25 s.
  @ViewBuilder
  private func flare(at point: CGPoint?, scale: CGFloat) -> some View {
    if let point {
      ZStack {
        Ellipse()
          .fill(LabColor.lumi.opacity(0.405))
          .frame(width: 52 * scale, height: 28 * scale)
          .blur(radius: 5 * scale)
        Circle()
          .fill(.white.opacity(0.855))
          .frame(width: 12 * scale, height: 12 * scale)
          .blur(radius: 1.25 * scale)
      }
      .scaleEffect(1 + 0.8 * flareBoost)
      .brightness(0.25 * flareBoost)
      .position(point)
    }
  }
}

// MARK: - The light

/// Lumi’s beam at a tilt: to the surface, then out into the air bent away from straight up,
/// with a reflection back into the glass that grows to all of it past 41.8°. In the vine it
/// zigzags off the walls, leaking at the first bounce until the tilt passes the tipping point.
struct PondLightPath {
  var tilt: Double
  var map: PondMap
  var inVine: Bool

  private var radians: Double { tilt * .pi / 180 }
  var reflectance: Double { GlassOptics.reflectance(forTilt: tilt) }
  var airAngle: Double? { GlassOptics.airAngle(forTilt: tilt) }
  var isStuck: Bool { airAngle == nil }

  /// Pond: where the beam meets the surface, on the fold.
  var exitPoint: CGPoint {
    let origin = map.lumiCenter
    let rise = origin.y - map.surfaceY
    return CGPoint(x: origin.x + rise * CGFloat(tan(radians)), y: map.surfaceY)
  }

  /// Vine: where the beam first meets the top wall.
  var firstBounce: CGPoint {
    let origin = map.vineLumi
    return CGPoint(x: origin.x + map.vineHalfBore * CGFloat(tan(radians)), y: origin.y - map.vineHalfBore)
  }

  var flarePoint: CGPoint? {
    if inVine { return isStuck ? nil : firstBounce }
    return exitPoint
  }

  /// The zigzag from Lumi to the lily’s end of the vine, wall to wall.
  var zigzag: [CGPoint] {
    let origin = map.vineLumi
    let step = 2 * map.vineHalfBore * CGFloat(tan(radians))
    var points = [origin, firstBounce]
    guard step > 0.5 else { return points }
    var top = true
    while let last = points.last, last.x < map.vineTipX, points.count < 80 {
      top.toggle()
      let next = CGPoint(x: last.x + step, y: map.vineCenterY + (top ? -1 : 1) * map.vineHalfBore)
      if next.x >= map.vineTipX {
        let fraction = (map.vineTipX - last.x) / step
        points.append(CGPoint(x: map.vineTipX, y: last.y + (next.y - last.y) * fraction))
        break
      }
      points.append(next)
    }
    return points
  }

  func draw(in context: inout GraphicsContext, won: Bool) {
    if inVine {
      drawVine(in: &context, won: won)
    } else {
      drawPond(in: &context)
    }
  }

  private func drawPond(in context: inout GraphicsContext) {
    let origin = map.lumiCenter
    let exit = exitPoint
    let scale = map.pondScale
    Beam.stroke(from: origin, to: exit, strength: 1, scale: scale, in: &context)

    if let air = airAngle {
      let direction = CGVector(dx: sin(air * .pi / 180), dy: -cos(air * .pi / 180))
      let end = Beam.reach(from: exit, direction: direction, in: map.size)
      // Physically faint near 42°, but the skimming beam is the point of beat b, so keep it visible.
      let transmitted = max(0.55, 1 - reflectance)
      Beam.stroke(from: exit, to: end, strength: transmitted, scale: scale, fades: true, in: &context)
    }

    let down = CGVector(dx: sin(radians), dy: cos(radians))
    let floorDrop = map.floorY - exit.y
    let landing = CGPoint(x: exit.x + floorDrop * down.dx / max(0.01, down.dy), y: map.floorY)
    if isStuck {
      mirrorShine(at: exit, scale: scale, in: &context)
      Beam.stroke(from: exit, to: landing, strength: 1, scale: scale, in: &context)
      landingGlow(at: landing, scale: scale, in: &context)
    } else {
      Beam.stroke(from: exit, to: landing, strength: GlassOptics.drawnReflection(forTilt: tilt), scale: scale, weak: true, fades: true, in: &context)
    }
  }

  private func drawVine(in context: inout GraphicsContext, won: Bool) {
    let scale = map.vineScale
    if won {
      let fill = map.vineRect.insetBy(dx: 8 * scale, dy: 8 * scale)
      context.drawLayer { layer in
        layer.addFilter(.blur(radius: 5 * scale))
        layer.fill(
          Path(roundedRect: fill, cornerRadius: fill.height / 2),
          with: .linearGradient(
            Gradient(stops: [
              .init(color: Color(red: 1, green: 214 / 255, blue: 138 / 255).opacity(0.1), location: 0),
              .init(color: Color(red: 1, green: 214 / 255, blue: 138 / 255).opacity(0.32), location: 0.5),
              .init(color: Color(red: 1, green: 227 / 255, blue: 243 / 255).opacity(0.3), location: 1)
            ]),
            startPoint: CGPoint(x: fill.minX, y: fill.midY),
            endPoint: CGPoint(x: fill.maxX, y: fill.midY)
          )
        )
      }
    }

    let points = zigzag
    if isStuck {
      Beam.stroke(points, strength: 1, scale: scale, weak: true, in: &context)
      if let last = points.last {
        Beam.stroke(from: last, to: map.lilyHeart, strength: 1, scale: scale, weak: true, in: &context)
      }
      return
    }

    // Under the tipping point most light escapes at the first bounce; what stays inside is the
    // surface’s share per bounce, drawn no fainter than 12%, and it fades out before the tip.
    Beam.stroke(from: points[0], to: points[1], strength: 1, scale: scale, weak: true, in: &context)
    if let air = airAngle {
      let direction = CGVector(dx: sin(air * .pi / 180), dy: -cos(air * .pi / 180))
      let length = 150 * scale
      let end = CGPoint(x: points[1].x + direction.dx * length, y: points[1].y + direction.dy * length)
      Beam.stroke(from: points[1], to: end, strength: max(0.5, 1 - reflectance), scale: scale, fades: true, in: &context)
    }
    let kept = GlassOptics.drawnReflection(forTilt: tilt)
    let leftover = Array(points.dropFirst())
    let segments = min(5, leftover.count - 1)
    guard segments > 0 else { return }
    for index in 0..<segments {
      let fade = 1 - Double(index) / Double(segments)
      Beam.stroke(from: leftover[index], to: leftover[index + 1], strength: kept * fade, scale: scale, weak: true, in: &context)
    }
  }

  /// Past 42° the surface shines like a mirror where the beam meets it.
  private func mirrorShine(at point: CGPoint, scale: CGFloat, in context: inout GraphicsContext) {
    let width = 180 * scale
    let rect = CGRect(x: point.x - width / 2, y: point.y - 1.5, width: width, height: 3)
    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 0.75))
      layer.fill(Path(rect), with: .linearGradient(
        Gradient(colors: [.white.opacity(0), .white.opacity(0.75), .white.opacity(0)]),
        startPoint: CGPoint(x: rect.minX, y: rect.midY),
        endPoint: CGPoint(x: rect.maxX, y: rect.midY)
      ))
    }
  }

  private func landingGlow(at point: CGPoint, scale: CGFloat, in context: inout GraphicsContext) {
    let rect = CGRect(x: point.x - 30 * scale, y: point.y - 8 * scale, width: 60 * scale, height: 16 * scale)
    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 4 * scale))
      layer.fill(Path(ellipseIn: rect), with: .color(LabColor.beamGlow.opacity(0.45)))
    }
  }
}

/// A beam of light in three passes: a wide amber bloom, a warm glow and a bright core.
enum Beam {
  static func stroke(from start: CGPoint, to end: CGPoint, strength: Double, scale: CGFloat,
                     weak: Bool = false, fades: Bool = false, in context: inout GraphicsContext) {
    var path = Path()
    path.move(to: start)
    path.addLine(to: end)
    draw(path, from: start, to: end, strength: strength, scale: scale, weak: weak, fades: fades, in: &context)
  }

  static func stroke(_ points: [CGPoint], strength: Double, scale: CGFloat, weak: Bool = false,
                     in context: inout GraphicsContext) {
    guard let first = points.first, let last = points.last, points.count > 1 else { return }
    var path = Path()
    path.addLines(points)
    draw(path, from: first, to: last, strength: strength, scale: scale, weak: weak, fades: false, in: &context)
  }

  private static func draw(_ path: Path, from start: CGPoint, to end: CGPoint, strength: Double, scale: CGFloat,
                           weak: Bool, fades: Bool, in context: inout GraphicsContext) {
    guard strength > 0.01 else { return }
    let passes: [(color: Color, opacity: Double, width: CGFloat, blur: CGFloat)] = [
      (LabColor.amber, 0.28, weak ? 16 : 20, 7),
      (LabColor.beamGlow, 0.7, weak ? 5.6 : 7, 1.5),
      (LabColor.beamCore, 1, weak ? 1.92 : 2.4, 0)
    ]
    for pass in passes {
      let opacity = pass.opacity * strength
      let shading: GraphicsContext.Shading = fades
        ? .linearGradient(
          Gradient(stops: [
            .init(color: pass.color.opacity(opacity), location: 0),
            .init(color: pass.color.opacity(opacity * 0.6), location: 0.55),
            .init(color: pass.color.opacity(0), location: 1)
          ]),
          startPoint: start,
          endPoint: end
        )
        : .color(pass.color.opacity(opacity))
      let style = StrokeStyle(lineWidth: pass.width * scale, lineCap: .round, lineJoin: .round)
      if pass.blur > 0 {
        context.drawLayer { layer in
          layer.addFilter(.blur(radius: pass.blur * scale))
          layer.stroke(path, with: shading, style: style)
        }
      } else {
        context.stroke(path, with: shading, style: style)
      }
    }
  }

  /// Where a ray from a point leaves the space.
  static func reach(from point: CGPoint, direction: CGVector, in size: CGSize) -> CGPoint {
    var distance = CGFloat.greatestFiniteMagnitude
    if direction.dy < 0 { distance = min(distance, -point.y / direction.dy) }
    if direction.dx > 0 { distance = min(distance, (size.width - point.x) / direction.dx) }
    if direction.dx < 0 { distance = min(distance, -point.x / direction.dx) }
    if distance == .greatestFiniteMagnitude { distance = size.width }
    return CGPoint(x: point.x + direction.dx * distance, y: point.y + direction.dy * distance)
  }
}

// MARK: - The still scene

/// Sky, moon, hills and reeds above the surface; magic glass, crystals and the pond floor below.
/// It depends only on the layout, so it redraws when the space changes, not with the tilt.
private struct PondBackdrop: View, Equatable {
  var map: PondMap
  var showsVine: Bool
  var showsFold: Bool

  var body: some View {
    Canvas { context, size in
      drawSky(in: &context, size: size)
      drawMoon(in: &context)
      drawHills(in: &context)
      drawReeds(in: &context)
      drawGlass(in: &context, size: size)
      drawFloor(in: &context)
      drawCrystals(in: &context)
      drawSurface(in: &context)
      drawPads(in: &context)
      if showsVine {
        drawVine(in: &context)
      } else {
        drawBud(in: &context)
      }
    }
    .accessibilityHidden(true)
  }

  private func drawSky(in context: inout GraphicsContext, size: CGSize) {
    let sky = CGRect(x: 0, y: 0, width: size.width, height: map.surfaceY)
    context.fill(Path(sky), with: .linearGradient(
      Gradient(stops: [
        .init(color: LabColor.buttonInk, location: 0),
        .init(color: LabColor.skyMiddle, location: 0.7),
        .init(color: LabColor.skyHorizon, location: 1)
      ]),
      startPoint: .zero,
      endPoint: CGPoint(x: 0, y: sky.maxY)
    ))
    let glow = CGRect(x: map.x(-133.8), y: map.y(395), width: 936.6 * map.sx, height: 160 * map.up)
    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 23 * map.skyScale))
      layer.fill(Path(ellipseIn: glow), with: .color(LabColor.horizonGlow.opacity(0.22)))
    }
  }

  private func drawMoon(in context: inout GraphicsContext) {
    // In a short sky the moon stays clear of the status bar.
    let designed = showsVine ? map.point(400, 150) : map.point(548, 186)
    let center = CGPoint(x: designed.x, y: max(designed.y, min(map.surfaceY - 60, 110)))
    let scale = map.ornamentScale
    func disc(_ radius: CGFloat) -> Path {
      Path(ellipseIn: CGRect(x: center.x - radius * scale, y: center.y - radius * scale, width: 2 * radius * scale, height: 2 * radius * scale))
    }
    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 20 * scale))
      layer.fill(disc(96), with: .color(LabColor.moonGlow.opacity(0.14)))
    }
    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 7 * scale))
      layer.fill(disc(40), with: .color(LabColor.moonHalo.opacity(0.3)))
    }
    context.fill(disc(24), with: .radialGradient(
      Gradient(stops: [
        .init(color: LabColor.moonCore, location: 0),
        .init(color: LabColor.moonHalo, location: 0.7),
        .init(color: LabColor.moonRim, location: 1)
      ]),
      center: CGPoint(x: center.x - 3.6 * scale, y: center.y - 3.6 * scale),
      startRadius: 0,
      endRadius: 30 * scale
    ))
    for crater in [(x: 7.0, y: 6.0, w: 8.0, h: 6.8), (x: -6.6, y: -5.2, w: 5.2, h: 4.4)] {
      let rect = CGRect(
        x: center.x + (crater.x - crater.w / 2) * scale,
        y: center.y + (crater.y - crater.h / 2) * scale,
        width: crater.w * scale,
        height: crater.h * scale
      )
      context.fill(Path(ellipseIn: rect), with: .color(LabColor.moonCrater.opacity(0.55)))
    }
  }

  private func drawHills(in context: inout GraphicsContext) {
    var far = Path()
    far.move(to: map.point(0, 476))
    far.addLine(to: map.point(0, 441))
    far.addCurve(to: map.point(230, 431), control1: map.point(70, 425), control2: map.point(150, 437))
    far.addCurve(to: map.point(480, 437), control1: map.point(320, 423), control2: map.point(400, 443))
    far.addCurve(to: map.point(669, 433), control1: map.point(560, 431), control2: map.point(620, 419))
    far.addLine(to: map.point(669, 476))
    far.closeSubpath()
    context.fill(far, with: .color(LabColor.farHills))

    var near = Path()
    near.move(to: map.point(0, 476))
    near.addLine(to: map.point(0, 455))
    near.addCurve(to: map.point(260, 455), control1: map.point(90, 445), control2: map.point(170, 461))
    near.addCurve(to: map.point(540, 455), control1: map.point(360, 448), control2: map.point(450, 464))
    near.addCurve(to: map.point(669, 455), control1: map.point(600, 450), control2: map.point(640, 451))
    near.addLine(to: map.point(669, 476))
    near.closeSubpath()
    context.fill(near, with: .color(LabColor.nearHills))
  }

  private func drawReeds(in context: inout GraphicsContext) {
    let reeds: [(x: CGFloat, top: CGFloat, lean: CGFloat, tilt: Double)] = [
      (26, 383, -8, -9), (50, 355, -4, 6), (76, 397, -12, 15), (84, 419, -5, -6),
      (606, 389, -10, -12), (635, 363, 4, 7.5), (661, 405, 10, 12)
    ]
    let scale = map.ornamentScale
    for reed in reeds {
      let base = map.point(reed.x - 2, 479)
      let top = CGPoint(x: map.x(reed.x - 2 + reed.lean), y: map.surfaceY - (479 - reed.top) * scale)
      var stem = Path()
      stem.move(to: base)
      stem.addQuadCurve(to: top, control: CGPoint(x: base.x + (top.x - base.x) * 0.2, y: (base.y + top.y) / 2))
      context.stroke(stem, with: .color(LabColor.reed), style: StrokeStyle(lineWidth: 3 * scale, lineCap: .round))

      var cattail = context
      cattail.translateBy(x: top.x, y: top.y + 9 * scale)
      cattail.rotate(by: .degrees(reed.tilt))
      cattail.fill(Path(ellipseIn: CGRect(x: -3.6 * scale, y: -12 * scale, width: 7.2 * scale, height: 24 * scale)), with: .color(LabColor.reed))
    }
  }

  private func drawGlass(in context: inout GraphicsContext, size: CGSize) {
    let glass = CGRect(x: 0, y: map.surfaceY, width: size.width, height: max(0, size.height - map.surfaceY))
    context.fill(Path(glass), with: .linearGradient(
      Gradient(stops: [
        .init(color: LabColor.glassTop, location: 0),
        .init(color: LabColor.glassShallow, location: 0.22),
        .init(color: LabColor.glassMiddle, location: 0.58),
        .init(color: LabColor.glassDeep, location: 1)
      ]),
      startPoint: CGPoint(x: 0, y: glass.minY),
      endPoint: CGPoint(x: 0, y: glass.maxY)
    ))

    // Facets: faint sheets of light through the glass.
    let facets: [[(x: CGFloat, bottom: Bool)]] = [
      [(0, false), (150, false), (60, true), (0, true)],
      [(60, false), (330, false), (240, true), (130, true)],
      [(250, false), (520, false), (430, true), (320, true)],
      [(470, false), (669, false), (669, true), (560, true)]
    ]
    for facet in facets {
      var path = Path()
      for (index, corner) in facet.enumerated() {
        let point = CGPoint(x: map.x(corner.x), y: corner.bottom ? glass.maxY : glass.minY)
        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
      }
      path.closeSubpath()
      context.fill(path, with: .linearGradient(
        Gradient(stops: [
          .init(color: .white.opacity(0.1), location: 0),
          .init(color: .white.opacity(0.025), location: 0.6),
          .init(color: .white.opacity(0), location: 1)
        ]),
        startPoint: CGPoint(x: 0, y: glass.minY),
        endPoint: CGPoint(x: 0, y: glass.maxY)
      ))
    }

    // Light shafts from the surface.
    for shaft in [(x: 100.0, w: 145.0), (x: 250, w: 134), (x: 400, w: 154), (x: 540, w: 125)] {
      var path = Path()
      let top = map.surfaceY
      let bottom = top + 260 * map.down
      path.move(to: CGPoint(x: map.x(shaft.x), y: top))
      path.addLine(to: CGPoint(x: map.x(shaft.x + 40), y: top))
      path.addLine(to: CGPoint(x: map.x(shaft.x + shaft.w), y: bottom))
      path.addLine(to: CGPoint(x: map.x(shaft.x + 15), y: bottom))
      path.closeSubpath()
      context.drawLayer { layer in
        layer.addFilter(.blur(radius: 6 * map.pondScale))
        layer.fill(path, with: .linearGradient(
          Gradient(colors: [LabColor.shaft.opacity(0.15), LabColor.shaft.opacity(0)]),
          startPoint: CGPoint(x: 0, y: top),
          endPoint: CGPoint(x: 0, y: bottom)
        ))
      }
    }

    // Deep glass under the pond floor, behind the controls.
    let deepTop = map.y(620)
    let deep = CGRect(x: 0, y: deepTop, width: size.width, height: max(0, size.height - deepTop))
    context.fill(Path(deep), with: .linearGradient(
      Gradient(stops: [
        .init(color: LabColor.backgroundBottom.opacity(0), location: 0),
        .init(color: LabColor.backgroundBottom.opacity(0.7), location: 0.35),
        .init(color: LabColor.shadow.opacity(0.92), location: 1)
      ]),
      startPoint: CGPoint(x: 0, y: deep.minY),
      endPoint: CGPoint(x: 0, y: deep.maxY)
    ))
  }

  private func drawFloor(in context: inout GraphicsContext) {
    var floor = Path()
    floor.move(to: map.point(0, 622))
    floor.addLine(to: map.point(0, 585))
    floor.addCurve(to: map.point(260, 582), control1: map.point(90, 567), control2: map.point(170, 593))
    floor.addCurve(to: map.point(540, 578), control1: map.point(360, 569), control2: map.point(440, 592))
    floor.addCurve(to: map.point(669, 576), control1: map.point(600, 571), control2: map.point(640, 582))
    floor.addLine(to: map.point(669, 622))
    floor.closeSubpath()
    context.fill(floor, with: .linearGradient(
      Gradient(colors: [LabColor.floorTop, LabColor.floorBottom]),
      startPoint: map.point(0, 576),
      endPoint: map.point(0, 622)
    ))
  }

  private func drawCrystals(in context: inout GraphicsContext) {
    // Clusters of glass crystals on the pond floor: pink, lavender and aqua.
    let cluster: [(dx: CGFloat, height: CGFloat, width: CGFloat)] = [(0, 34, 14), (12, 52, 18), (27, 40, 14), (39, 26, 12)]
    let tints: [Color] = [LabColor.crystalPink, LabColor.crystalLavender, LabColor.crystalAqua]
    let clusters: [(x: CGFloat, tint: Int)] = [(34, 0), (296, 1), (588, 2)]
    let scale = map.pondScale
    for group in clusters {
      for (index, crystal) in cluster.enumerated() {
        let tint = tints[(group.tint + index) % tints.count]
        let base = map.point(group.x + crystal.dx + crystal.width / 2, 606)
        draw(crystal: base, width: crystal.width * scale, height: crystal.height * scale, tint: tint, in: &context)
      }
    }
    for crystal in [(x: 466.5, h: 42.0, w: 17.0), (x: 483, h: 30, w: 14), (x: 450, h: 23, w: 12)] {
      draw(crystal: map.point(CGFloat(crystal.x), 603), width: CGFloat(crystal.w) * scale, height: CGFloat(crystal.h) * scale, tint: LabColor.crystalIce, in: &context)
    }
  }

  private func draw(crystal base: CGPoint, width: CGFloat, height: CGFloat, tint: Color, in context: inout GraphicsContext) {
    var path = Path()
    path.move(to: CGPoint(x: base.x - width / 2, y: base.y))
    path.addLine(to: CGPoint(x: base.x - width * 0.4, y: base.y - height * 0.8))
    path.addLine(to: CGPoint(x: base.x, y: base.y - height))
    path.addLine(to: CGPoint(x: base.x + width * 0.4, y: base.y - height * 0.8))
    path.addLine(to: CGPoint(x: base.x + width / 2, y: base.y))
    path.closeSubpath()
    context.drawLayer { layer in
      layer.addFilter(.shadow(color: tint.opacity(0.55), radius: 5 * map.pondScale))
      layer.fill(path, with: .linearGradient(
        Gradient(colors: [tint.opacity(0.85), tint.opacity(0.12)]),
        startPoint: CGPoint(x: base.x, y: base.y - height),
        endPoint: base
      ))
    }
  }

  private func drawSurface(in context: inout GraphicsContext) {
    let width = map.size.width
    let glow = CGRect(x: 0, y: map.surfaceY - 12 * map.pondScale, width: width, height: 24 * map.pondScale)
    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 5))
      layer.fill(Path(glow), with: .color(LabColor.glassAqua.opacity(0.16)))
    }
    let line = CGRect(x: 0, y: map.surfaceY - 1, width: width, height: 2.5)
    context.fill(Path(line), with: .linearGradient(
      Gradient(stops: [
        .init(color: LabColor.glassLine.opacity(0.2), location: 0),
        .init(color: LabColor.glassLine.opacity(0.9), location: 0.3),
        .init(color: LabColor.glassLine.opacity(0.6), location: 0.6),
        .init(color: LabColor.glassLine.opacity(0.9), location: 0.85),
        .init(color: LabColor.glassLine.opacity(0.2), location: 1)
      ]),
      startPoint: CGPoint(x: 0, y: line.midY),
      endPoint: CGPoint(x: width, y: line.midY)
    ))
    if showsFold {
      let band = CGRect(x: 0, y: map.surfaceY - 22, width: width, height: 44)
      context.fill(Path(band), with: .linearGradient(
        Gradient(colors: [.white.opacity(0), .white.opacity(0.04), .white.opacity(0)]),
        startPoint: CGPoint(x: 0, y: band.minY),
        endPoint: CGPoint(x: 0, y: band.maxY)
      ))
    }
  }

  private func drawPads(in context: inout GraphicsContext) {
    let pads: [(x: CGFloat, width: CGFloat, height: CGFloat)] = showsVine
      ? [(46, 80, 13)]
      : [(36, 80, 13), (578, 68, 12)]
    let scale = map.pondScale
    for pad in pads {
      let rect = CGRect(x: map.x(pad.x), y: map.surfaceY - 5.5 * scale, width: pad.width * map.sx, height: pad.height * scale)
      context.fill(Path(ellipseIn: rect), with: .linearGradient(
        Gradient(colors: [LabColor.padTop, LabColor.padBottom]),
        startPoint: CGPoint(x: rect.midX, y: rect.minY),
        endPoint: CGPoint(x: rect.midX, y: rect.maxY)
      ))
      let sheen = CGRect(x: rect.minX + rect.width * 0.22, y: rect.minY + 2 * scale, width: rect.width * 0.3, height: 4 * scale)
      context.fill(Path(ellipseIn: sheen), with: .color(LabColor.padSheen.opacity(0.35)))
    }
  }

  /// The moon lily’s bud on its pad, before the challenge.
  private func drawBud(in context: inout GraphicsContext) {
    let scale = map.pondScale
    let base = CGPoint(x: map.x(612), y: map.surfaceY - 9 * scale)
    let glow = CGRect(x: base.x - 12 * scale, y: base.y - 14 * scale, width: 24 * scale, height: 28 * scale)
    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 4 * scale))
      layer.fill(Path(ellipseIn: glow), with: .color(LabColor.lilyGlow.opacity(0.22)))
    }
    for side in [-1.0, 1.0] {
      var petal = context
      petal.translateBy(x: base.x + CGFloat(side) * 4 * scale, y: base.y)
      petal.rotate(by: .degrees(14 * side))
      petal.fill(
        Path(ellipseIn: CGRect(x: -4.6 * scale, y: -11 * scale, width: 9.2 * scale, height: 22 * scale)),
        with: .linearGradient(
          Gradient(colors: [LabColor.budTop, LabColor.budBottom]),
          startPoint: CGPoint(x: 0, y: -11 * scale),
          endPoint: CGPoint(x: 0, y: 11 * scale)
        )
      )
    }
  }

  /// The crystal vine: a glass tube grown out of the pond, with a stalk and a few leaves.
  private func drawVine(in context: inout GraphicsContext) {
    let scale = map.vineScale
    var stalk = Path()
    stalk.move(to: map.point(88, 478))
    stalk.addCurve(to: CGPoint(x: map.x(70), y: map.vineRect.maxY - 4 * scale), control1: map.point(66, 445), control2: map.point(40, 457))
    context.stroke(stalk, with: .color(LabColor.vineStalk), style: StrokeStyle(lineWidth: 7 * scale, lineCap: .round))

    let leaves: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, turn: Double)] = [
      (70, 447.5, 10, 22, 40), (71, 415, 10, 22, -30),
      (200, 361, 8, 18, 30), (368, 437, 8, 18, 160), (489, 357, 8, 18, 30)
    ]
    for leaf in leaves {
      var layer = context
      let centre = leaf.x > 100
        ? CGPoint(x: map.x(leaf.x), y: map.vineCenterY + (leaf.y - 387) * scale)
        : map.point(leaf.x, leaf.y)
      layer.translateBy(x: centre.x, y: centre.y)
      layer.rotate(by: .degrees(leaf.turn))
      layer.fill(
        Path(ellipseIn: CGRect(x: -leaf.w / 2 * scale, y: -leaf.h / 2 * scale, width: leaf.w * scale, height: leaf.h * scale)),
        with: .linearGradient(
          Gradient(colors: [LabColor.leafTop.opacity(0.9), LabColor.leafBottom.opacity(0.9)]),
          startPoint: CGPoint(x: 0, y: -leaf.h / 2 * scale),
          endPoint: CGPoint(x: 0, y: leaf.h / 2 * scale)
        )
      )
    }

    let tube = map.vineRect
    let shape = Path(roundedRect: tube, cornerRadius: tube.height / 2)
    context.drawLayer { layer in
      layer.addFilter(.shadow(color: LabColor.vineShadow.opacity(0.22), radius: 18 * scale))
      layer.fill(shape, with: .linearGradient(
        Gradient(stops: [
          .init(color: LabColor.vineGlass.opacity(0.28), location: 0),
          .init(color: LabColor.vineCore.opacity(0.08), location: 0.5),
          .init(color: LabColor.vineGlass.opacity(0.2), location: 1)
        ]),
        startPoint: CGPoint(x: tube.midX, y: tube.minY),
        endPoint: CGPoint(x: tube.midX, y: tube.maxY)
      ))
    }
    context.stroke(shape, with: .color(LabColor.vineEdge.opacity(0.22)), lineWidth: 1)
    let sheen = CGRect(x: map.x(80), y: tube.minY + 5 * scale, width: map.x(516) - map.x(80), height: 3)
    context.fill(Path(roundedRect: sheen, cornerRadius: 1.5), with: .linearGradient(
      Gradient(colors: [.white.opacity(0), .white.opacity(0.55), .white.opacity(0)]),
      startPoint: CGPoint(x: sheen.minX, y: sheen.midY),
      endPoint: CGPoint(x: sheen.maxX, y: sheen.midY)
    ))

    var stem = Path()
    stem.move(to: CGPoint(x: map.x(538), y: map.vineCenterY - 0.5 * scale))
    stem.addQuadCurve(to: CGPoint(x: map.lilyHeart.x - 8 * scale, y: map.vineCenterY - 0.5 * scale), control: CGPoint(x: map.x(552), y: map.vineCenterY - 2.5 * scale))
    context.stroke(stem, with: .color(LabColor.leafBottom), style: StrokeStyle(lineWidth: 4 * scale, lineCap: .round))
  }
}

/// Stars twinkle, fireflies drift on 8 s loops and pond caustics shift on a 12 s loop.
/// Everything holds still with Reduce Motion.
private struct PondAmbience: View {
  var map: PondMap
  var showsVine: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
      let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
      Canvas { context, _ in
        drawStars(at: time, in: &context)
        drawCaustics(at: time, in: &context)
        drawMotes(in: &context)
        drawFireflies(at: time, in: &context)
      }
    }
    .accessibilityHidden(true)
  }

  private func drawStars(at time: TimeInterval, in context: inout GraphicsContext) {
    let skyBottom = map.surfaceY - 60 * map.up
    guard skyBottom > 20 else { return }
    for index in 0..<34 {
      let x = CGFloat((index * 137 + 47) % 997) / 997 * map.size.width
      let y = CGFloat((index * 281 + 79) % 991) / 991 * skyBottom
      let bright = index % 11 == 0
      let size: CGFloat = bright ? 3.2 : 1.4 + CGFloat(index % 3) * 0.6
      let period = 3 + 3 * Double((index * 61) % 100) / 100
      let twinkle = 0.4 + 0.6 * (0.5 + 0.5 * sin(2 * .pi * time / period + Double(index) * 1.7))
      if bright {
        let halo = CGRect(x: x - 6, y: y - 6, width: 12, height: 12)
        context.fill(Path(ellipseIn: halo), with: .radialGradient(
          Gradient(colors: [.white.opacity(0.35 * twinkle), .white.opacity(0)]),
          center: CGPoint(x: x, y: y), startRadius: 0, endRadius: 6
        ))
      }
      context.fill(
        Path(ellipseIn: CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)),
        with: .color(.white.opacity((bright ? 1 : 0.47) * twinkle))
      )
    }
  }

  private static let caustics: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = [
    (426, 510, 17, 10), (648, 499, 40, 7), (140, 499, 18, 10), (478, 496, 17, 6), (88, 502, 48, 5),
    (576, 512, 50, 10), (166, 504, 48, 7), (271, 508, 36, 7), (492, 492, 42, 8), (208, 512, 52, 9),
    (614, 488, 39, 6), (373, 505, 50, 8), (299, 487, 40, 8), (339, 505, 29, 10), (200, 499, 23, 9),
    (158, 501, 31, 5), (550, 510, 49, 9), (17, 505, 38, 9), (25, 486, 19, 6), (6, 500, 50, 6),
    (135, 502, 25, 8), (283, 502, 44, 7), (41, 490, 45, 11), (619, 497, 20, 6), (114, 485, 26, 9), (322, 512, 19, 7)
  ]

  private func drawCaustics(at time: TimeInterval, in context: inout GraphicsContext) {
    let loop = 2 * .pi * time / 12
    for (index, caustic) in Self.caustics.enumerated() {
      let phase = Double(index) * 0.9
      let drift = CGFloat(6 * sin(loop + phase))
      let pulse = 0.7 + 0.3 * sin(2 * loop + phase)
      let center = CGPoint(x: map.x(caustic.x) + drift * map.sx, y: map.y(caustic.y))
      let rect = CGRect(x: center.x - caustic.w / 2 * map.sx, y: center.y - caustic.h / 2 * map.down, width: caustic.w * map.sx, height: caustic.h * map.down)
      context.fill(Path(ellipseIn: rect), with: .radialGradient(
        Gradient(colors: [LabColor.caustic.opacity(0.16 * pulse), LabColor.caustic.opacity(0)]),
        center: center, startRadius: 0, endRadius: max(rect.width, rect.height) / 2
      ))
    }
  }

  private func drawMotes(in context: inout GraphicsContext) {
    let motes: [(x: CGFloat, y: CGFloat)] = [
      (3, 515), (276, 523), (157, 601), (520, 586), (292, 595), (644, 590), (443, 568),
      (233, 553), (332, 561), (379, 582), (445, 574), (488, 598), (565, 607), (293, 560)
    ]
    for mote in motes {
      let center = map.point(mote.x, mote.y)
      context.fill(Path(ellipseIn: CGRect(x: center.x - 1.2, y: center.y - 1.2, width: 2.4, height: 2.4)), with: .color(LabColor.mote.opacity(0.55)))
    }
  }

  private func drawFireflies(at time: TimeInterval, in context: inout GraphicsContext) {
    let fireflies: [(x: CGFloat, y: CGFloat, size: CGFloat)] = showsVine
      ? [(118, 300, 14), (210, 255, 12), (470, 300, 16), (620, 240, 12), (560, 440, 12)]
      : [(98, 381, 18), (132, 349, 14), (470, 417, 16), (512, 443, 12), (590, 387, 16), (40, 413, 12)]
    let loop = 2 * .pi * time / 8
    let scale = map.ornamentScale
    for (index, firefly) in fireflies.enumerated() {
      let phase = Double(index) * 1.9
      let dx = CGFloat(10 * sin(loop + phase) + 4 * sin(2 * loop + phase * 2)) * scale
      let dy = CGFloat(6 * cos(loop + phase * 1.3) + 3 * sin(3 * loop + phase)) * scale
      let center = CGPoint(x: map.x(firefly.x) + dx, y: map.y(firefly.y) + dy)
      let radius = firefly.size * scale
      let glow = 0.7 + 0.3 * sin(4 * loop + phase)
      context.fill(
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
        with: .radialGradient(
          Gradient(colors: [LabColor.label.opacity(0.45 * glow), LabColor.label.opacity(0)]),
          center: center, startRadius: 0, endRadius: radius
        )
      )
      let body = radius * 0.28
      context.fill(Path(ellipseIn: CGRect(x: center.x - body / 2, y: center.y - body / 2, width: body, height: body)), with: .color(LabColor.label))
    }
  }
}

// MARK: - The moon lily

/// The bud at the vine’s tip. It glows brighter on a near miss and opens when the light arrives.
private struct MoonLily: View {
  var bloom: Double
  var almost: Bool
  var scale: CGFloat

  var body: some View {
    ZStack {
      Ellipse()
        .fill(LabColor.lilyGlow.opacity(0.4 * bloom + (almost ? 0.45 : 0.22) * (1 - bloom)))
        .frame(width: (28 + 80 * bloom) * scale * (almost ? 1.3 : 1), height: (32 + 56 * bloom) * scale * (almost ? 1.3 : 1))
        .blur(radius: (4 + 7 * bloom) * scale)

      ForEach(0..<8, id: \.self) { index in
        petal(width: 13, height: 32, top: LabColor.lilyPetalTop, bottom: LabColor.lilyPetalBottom)
          .offset(y: -16 * scale * bloom)
          .rotationEffect(.degrees(Double(index) * 45))
          .scaleEffect(0.3 + 0.7 * bloom)
          .opacity(bloom)
      }
      ForEach(0..<5, id: \.self) { index in
        petal(width: 9, height: 20, top: .white, bottom: LabColor.lilyInner)
          .offset(y: -9 * scale * bloom)
          .rotationEffect(.degrees(Double(index) * 72 + 20))
          .scaleEffect(0.3 + 0.7 * bloom)
          .opacity(bloom)
      }
      Circle()
        .fill(LabColor.label)
        .frame(width: 11 * scale, height: 11 * scale)
        .shadow(color: LabColor.label.opacity(0.8), radius: 4 * scale)
        .opacity(bloom)

      HStack(spacing: -7 * scale) {
        petal(width: 17, height: 27, top: LabColor.budTop, bottom: LabColor.budBottom)
          .rotationEffect(.degrees(-14))
        petal(width: 17, height: 27, top: LabColor.budTop, bottom: LabColor.budBottom)
          .rotationEffect(.degrees(14))
      }
      .opacity(1 - bloom)
      .scaleEffect(1 - 0.4 * bloom)
    }
    .accessibilityHidden(true)
  }

  private func petal(width: CGFloat, height: CGFloat, top: Color, bottom: Color) -> some View {
    Ellipse()
      .fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
      .frame(width: width * scale, height: height * scale)
      .shadow(color: LabColor.lilyGlow.opacity(0.6), radius: 4 * scale)
  }
}

// MARK: - Why beats

/// The straight-up line at the exit point and the words the beat talks about.
private struct WhyMarks: View {
  var beat: Int
  var exit: CGPoint
  var map: PondMap

  var body: some View {
    let scale = map.pondScale
    ZStack(alignment: .topLeading) {
      Canvas { context, _ in
        var normal = Path()
        normal.move(to: CGPoint(x: exit.x, y: exit.y - min(beat == 2 ? 27 : 49, exit.y * 0.2)))
        normal.addLine(to: CGPoint(x: exit.x, y: min(exit.y + (beat == 2 ? 173 : 131) * scale, map.floorY + 30)))
        context.stroke(normal, with: .color(LabColor.glassLine.opacity(0.35)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 6]))

        guard beat == 2 else { return }
        let tipping = GlassOptics.criticalAngle * .pi / 180
        let length = 150 * scale
        var line = Path()
        line.move(to: exit)
        line.addLine(to: CGPoint(x: exit.x - CGFloat(sin(tipping)) * length, y: exit.y + CGFloat(cos(tipping)) * length))
        context.stroke(line, with: .color(LabColor.glassLine.opacity(0.85)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [6, 6]))

        var arc = Path()
        arc.addArc(center: exit, radius: 38 * scale, startAngle: .degrees(90), endAngle: .degrees(90 + GlassOptics.criticalAngle), clockwise: false)
        context.stroke(arc, with: .color(LabColor.glassLine.opacity(0.85)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
      }

      switch beat {
      case 0:
        label("bends away from straight up", ink: LabColor.lumi)
          .position(x: exit.x + 124 * map.sx, y: exit.y - min(185, exit.y * 0.55))
        label("in glass: slower", ink: LabColor.glassAqua)
          .position(x: exit.x + 50 * map.sx, y: exit.y + 44 * scale)
        label("in air: faster", ink: LabColor.primaryInk)
          .position(x: exit.x - 70 * map.sx, y: exit.y - 28)
      case 1:
        label("about 42°: skims the surface", ink: LabColor.lumi)
          .position(x: exit.x + 150 * map.sx, y: exit.y - 20)
      default:
        Text("42°")
          .font(.system(.subheadline, design: .rounded, weight: .semibold))
          .foregroundStyle(LabColor.glassLine)
          .position(x: exit.x - 44 * scale, y: exit.y + 50 * scale)
      }
    }
    .accessibilityHidden(true)
  }

  private func label(_ text: String, ink: Color) -> some View {
    SceneLabel(text: text, kind: .tinted(ink))
      .fixedSize()
  }
}

/// Hint level 2 marks where it matters: the vine’s walls in the challenge, the surface otherwise.
private struct HintMark: View {
  var map: PondMap
  var inVine: Bool
  var exit: CGPoint

  var body: some View {
    ZStack(alignment: .topLeading) {
      if inVine {
        let tube = map.vineRect.insetBy(dx: -4, dy: -4)
        RoundedRectangle(cornerRadius: tube.height / 2)
          .strokeBorder(LabColor.label.opacity(0.8), lineWidth: 2)
          .shadow(color: LabColor.label.opacity(0.7), radius: 8)
          .frame(width: tube.width, height: tube.height)
          .position(x: tube.midX, y: tube.midY)
        SceneLabel(text: "tilt past 42° so light bounces along here", kind: .tinted(LabColor.lumi))
          .fixedSize()
          .position(x: tube.midX, y: tube.minY - 22)
      } else {
        Capsule()
          .fill(LabColor.label.opacity(0.7))
          .frame(width: map.size.width * 0.9, height: 3)
          .shadow(color: LabColor.label.opacity(0.8), radius: 8)
          .position(x: map.size.width / 2, y: map.surfaceY)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
