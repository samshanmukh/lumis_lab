import SwiftUI

/// The two standing mirrors on the magic circle, with Lumi and every reflection.
/// Animatable on the mirror angle, so hinge smoothing and Show me moves redraw the whole scene.
struct MirrorSceneView: View, Animatable {
  var angle: Double
  var center: CGPoint
  var radiusX: CGFloat
  var style: MirrorSceneStyle

  var animatableData: Double {
    get { angle }
    set { angle = newValue }
  }

  private var radiusY: CGFloat { radiusX / 3 }
  private var scale: CGFloat { radiusX / 300 }

  var body: some View {
    let placements = MirrorOptics.placements(for: angle)
    let crowded = placements.filter { $0.opacity >= 1 }.count >= 7
    let reflections = placements.filter { !$0.isReal }.sorted { $0.depth < $1.depth }

    ZStack(alignment: .topLeading) {
      Color.clear

      floorGlowAndPulse

      Canvas { context, _ in
        drawFloor(in: &context)
        drawSlices(in: &context)
        drawTarget(in: &context)
      }

      ForEach(reflections) { placement in
        lumi(placement, crowded: crowded)
      }

      Canvas { context, _ in
        drawMirror(side: -1, in: &context)
        drawMirror(side: 1, in: &context)
      }

      if style.whyBeat == 1 {
        bounceArrows(placements, crowded: crowded)
      }

      lumi(placements[0], crowded: crowded)

      labels(placements, crowded: crowded)
    }
    .allowsHitTesting(false)
  }

  // MARK: Geometry

  private func point(_ degrees: Double, _ radius: CGFloat) -> CGPoint {
    let radians = degrees * .pi / 180
    return CGPoint(
      x: center.x + radiusX * radius * CGFloat(sin(radians)),
      y: center.y + radiusY * radius * CGFloat(cos(radians))
    )
  }

  private func lumiSize(_ placement: LumiPlacement, crowded: Bool) -> CGFloat {
    let depthScale = 0.68 + 0.32 * (1 + placement.depth) / 2
    return 156 * scale * CGFloat(depthScale) * (crowded ? 0.85 : 1)
  }

  private func lumiCenter(_ placement: LumiPlacement, size: CGFloat) -> CGPoint {
    let base = point(placement.degrees, 0.6)
    return CGPoint(x: base.x, y: base.y - size * 0.092)
  }

  private var mirrorEnds: (left: CGPoint, right: CGPoint) {
    (point(-angle / 2, 1), point(angle / 2, 1))
  }

  // MARK: Floor

  private var floorGlowAndPulse: some View {
    ZStack {
      Ellipse()
        .fill(RadialGradient(
          colors: [LabColor.glow.opacity(0.42), LabColor.glow.opacity(0)],
          center: .center,
          startRadius: 0,
          endRadius: radiusX
        ))
        .frame(width: radiusX * 2.1, height: radiusY * 2.1)
        .blur(radius: 12 * scale)
        .opacity(style.floorWarm ? 1 : 0)

      Ellipse()
        .stroke(LabColor.softLight.opacity(0.7), lineWidth: 3 * scale)
        .frame(width: radiusX * 2, height: radiusY * 2)
        .blur(radius: 3)
        .phaseAnimator([0.0, 1.0], trigger: style.floorPulse) { content, phase in
          content
            .opacity(phase)
            .scaleEffect(1 + 0.04 * phase)
        } animation: { _ in
          .easeOut(duration: 0.125)
        }
    }
    .position(center)
  }

  private func drawFloor(in context: inout GraphicsContext) {
    let glowRect = CGRect(
      x: center.x - radiusX * 1.08,
      y: center.y - radiusY * 1.1,
      width: radiusX * 2.16,
      height: radiusY * 2.2
    )
    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 14 * scale))
      layer.fill(Path(ellipseIn: glowRect), with: .color(LabColor.floorGlow.opacity(0.1)))
    }

    var circle = context
    circle.translateBy(x: center.x, y: center.y)
    circle.scaleBy(x: 1, y: radiusY / radiusX)
    circle.fill(
      Path(ellipseIn: CGRect(x: -radiusX, y: -radiusX, width: radiusX * 2, height: radiusX * 2)),
      with: .radialGradient(
        Gradient(stops: [
          .init(color: LabColor.floorInner.opacity(0.7), location: 0),
          .init(color: LabColor.doorLeaf.opacity(0.45), location: 0.6),
          .init(color: LabColor.floorOuter.opacity(0.15), location: 1)
        ]),
        center: .zero,
        startRadius: 0,
        endRadius: radiusX
      )
    )

    let dot = 2.6 * scale
    for index in 0..<64 {
      let position = point(Double(index) * 5.625, 1)
      context.fill(
        Path(ellipseIn: CGRect(x: position.x - dot / 2, y: position.y - dot / 2, width: dot, height: dot)),
        with: .color(LabColor.sceneLabelInk.opacity(0.35))
      )
    }

    var wedge = Path()
    wedge.move(to: center)
    let half = angle / 2
    for step in 0...24 {
      wedge.addLine(to: point(-half + angle * Double(step) / 24, 1))
    }
    wedge.closeSubpath()
    context.fill(wedge, with: .color(LabColor.glow.opacity(0.16)))
  }

  private func drawSlices(in context: inout GraphicsContext) {
    guard style.showsSliceEdges else { return }
    let style = StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [1, 6])
    for edge in MirrorOptics.sliceEdges(for: angle) {
      var line = Path()
      line.move(to: center)
      line.addLine(to: point(edge, 1))
      context.stroke(line, with: .color(LabColor.sceneLabelLine.opacity(0.35)), style: style)
    }
  }

  private func drawTarget(in context: inout GraphicsContext) {
    guard style.showsTarget else { return }
    let distance = abs(angle - style.targetAngle)
    let opacity = min(1, max(0, (distance - 1) / 3))
    guard opacity > 0 else { return }
    let dashes = StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [5, 7])
    for side in [-1.0, 1.0] {
      var line = Path()
      line.move(to: center)
      line.addLine(to: point(side * style.targetAngle / 2, 1))
      context.stroke(line, with: .color(LabColor.glow.opacity(0.5 * opacity)), style: dashes)
    }
  }

  // MARK: Mirrors

  private func drawMirror(side: Double, in context: inout GraphicsContext) {
    let end = point(side * angle / 2, 1)
    let rise = 104 * scale
    var glass = Path()
    glass.move(to: center)
    glass.addLine(to: end)
    glass.addLine(to: CGPoint(x: end.x, y: end.y - rise * 0.81))
    glass.addLine(to: CGPoint(x: center.x, y: center.y - rise))
    glass.closeSubpath()

    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 6 * scale))
      layer.fill(glass, with: .linearGradient(
        Gradient(stops: [
          .init(color: LabColor.glassFace.opacity(0.16), location: 0),
          .init(color: LabColor.glassFace.opacity(0.07), location: 0.55),
          .init(color: LabColor.glassFace.opacity(0), location: 1)
        ]),
        startPoint: CGPoint(x: center.x, y: center.y - rise / 2),
        endPoint: CGPoint(x: end.x, y: end.y - rise / 2)
      ))
    }

    var edge = Path()
    edge.move(to: center)
    edge.addLine(to: end)
    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 3 * scale))
      layer.stroke(edge, with: .color(LabColor.retry.opacity(0.35)), style: StrokeStyle(lineWidth: 10 * scale, lineCap: .round))
    }
    context.drawLayer { layer in
      layer.addFilter(.shadow(color: LabColor.mirrorGlow.opacity(0.9), radius: 4))
      layer.stroke(edge, with: .color(LabColor.mirrorEdge), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }
  }

  // MARK: Lumis

  private func lumi(_ placement: LumiPlacement, crowded: Bool) -> some View {
    let size = lumiSize(placement, crowded: crowded)
    let isBackInBeatOne = style.whyBeat == 0 && placement.bounces >= 2
    return LumiView(mood: style.mood, radius: size / 6, mirrored: placement.isMirrored)
      .scaleEffect(style.pulsingLumi == placement.index ? 1.22 : 1)
      .brightness(style.pulsingLumi == placement.index ? 0.12 : 0)
      .opacity(placement.opacity * (isBackInBeatOne ? 0.28 : 1))
      .position(lumiCenter(placement, size: size))
      .accessibilityHidden(true)
  }

  private func bounceArrows(_ placements: [LumiPlacement], crowded: Bool) -> some View {
    let back = placements.first { $0.bounces == 2 }
    let sides = placements.filter { $0.bounces == 1 }
    return Canvas { context, _ in
      guard let back else { return }
      let backSize = lumiSize(back, crowded: crowded)
      let target = lumiCenter(back, size: backSize)
      for side in sides {
        let size = lumiSize(side, crowded: crowded)
        let from = lumiCenter(side, size: size)
        let direction: CGFloat = from.x < target.x ? 1 : -1
        let start = CGPoint(x: from.x + direction * size * 0.26, y: from.y - size * 0.1)
        let end = CGPoint(x: target.x - direction * backSize * 0.24, y: target.y + backSize * 0.02)
        let control = CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - 26 * scale)
        var curve = Path()
        curve.move(to: start)
        curve.addQuadCurve(to: end, control: control)
        context.stroke(curve, with: .color(LabColor.label.opacity(0.85)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [5, 5]))

        let heading = atan2(end.y - control.y, end.x - control.x)
        var head = Path()
        head.move(to: CGPoint(x: end.x - 7 * cos(heading - 0.5), y: end.y - 7 * sin(heading - 0.5)))
        head.addLine(to: end)
        head.addLine(to: CGPoint(x: end.x - 7 * cos(heading + 0.5), y: end.y - 7 * sin(heading + 0.5)))
        context.stroke(head, with: .color(LabColor.label.opacity(0.85)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
      }
    }
  }

  // MARK: Labels

  @ViewBuilder
  private func labels(_ placements: [LumiPlacement], crowded: Bool) -> some View {
    let ends = mirrorEnds
    anchor(at: ends.left, alignment: .trailing, offset: CGSize(width: -7, height: 0)) {
      SceneLabel(text: "mirror", kind: .mirror)
    }
    anchor(at: ends.right, alignment: .leading, offset: CGSize(width: 7, height: 0)) {
      SceneLabel(text: "mirror", kind: .mirror)
    }
    anchor(at: point(0, 0.6), alignment: .top, offset: CGSize(width: 0, height: 18 * scale)) {
      SceneLabel(text: "real Lumi", kind: .real)
    }

    ForEach(placements.filter { labelText(for: $0) != nil }) { placement in
      let size = lumiSize(placement, crowded: crowded)
      let lumiPoint = lumiCenter(placement, size: size)
      anchor(at: CGPoint(x: lumiPoint.x, y: lumiPoint.y - size * 0.36), alignment: .center, offset: .zero) {
        SceneLabel(text: labelText(for: placement) ?? "", kind: .reflection)
      }
      .transition(.opacity)
    }

    if style.whyBeat == 2 {
      let count = MirrorOptics.count(for: angle)
      ForEach(0..<count, id: \.self) { index in
        Text("\(index + 1)")
          .font(.system(.body, design: .rounded, weight: .semibold))
          .foregroundStyle(index == 0 ? LabColor.label : LabColor.secondaryInk)
          .opacity(index < style.sliceReveal ? 1 : 0)
          .position(point(-Double(index) * angle, 1.16))
      }
    }
  }

  private func labelText(for placement: LumiPlacement) -> String? {
    guard !placement.isReal, placement.opacity >= 1 else { return nil }
    switch style.whyBeat {
    case 0: return placement.bounces == 1 ? "reflection" : nil
    case 1: return placement.bounces == 1 ? "reflection" : "reflection of a reflection"
    case 2: return nil
    default: return style.labelsReflections ? "reflection" : nil
    }
  }

  private func anchor<Content: View>(
    at point: CGPoint,
    alignment: Alignment,
    offset: CGSize,
    @ViewBuilder content: () -> Content
  ) -> some View {
    Color.clear
      .frame(width: 1, height: 1)
      .overlay(alignment: alignment) {
        content()
          .fixedSize()
          .offset(offset)
      }
      .position(point)
  }
}

/// What the scene shows around the Lumis on the current step.
struct MirrorSceneStyle: Equatable {
  var mood: LumiMood = .wonder
  var showsTarget = false
  var targetAngle: Double = 90
  var labelsReflections = false
  var whyBeat: Int?
  var showsSliceEdges = true
  var floorWarm = false
  var pulsingLumi: Int?
  var floorPulse = 0
  var sliceReveal = 0
}
