import SwiftUI

/// The inside of the Mirror Room used on the checkpoints: walls, sconces, the magic circle,
/// and the two standing mirrors drawn as the phone’s halves meeting at a glowing hinge.
/// Drawn from the design’s 475 × 669 half-screen artwork, fitted into `roomFrame`;
/// walls, ceiling and floor run out to the edges of the whole view.
struct MirrorRoomInterior: View {
  var roomFrame: CGRect
  var showsMirrors = true

  var body: some View {
    let art = RoomArt(frame: roomFrame)
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        Canvas { context, size in
          drawRoom(art, size: size, in: &context)
          if showsMirrors {
            drawMirrors(art, in: &context)
          }
        }

        LumiView(mood: .wonder, radius: 16 * art.scale)
          .position(art.point(255, 488))
          .accessibilityHidden(true)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
    .accessibilityElement()
    .accessibilityLabel("The Mirror Room. Two mirrors stand open like a book, with Lumi between them.")
  }

  private func drawRoom(_ art: RoomArt, size: CGSize, in context: inout GraphicsContext) {
    let backTopLeft = art.point(90, 92)
    let backTopRight = art.point(420, 92)
    let backBottomLeft = art.point(90, 392)
    let backBottomRight = art.point(420, 392)
    let width = size.width
    let height = size.height

    context.fill(
      polygon([.zero, CGPoint(x: width, y: 0), backTopRight, backTopLeft]),
      with: .linearGradient(Gradient(colors: [Color(red: 0.075, green: 0.055, blue: 0.3), Color(red: 0.125, green: 0.1, blue: 0.42)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: backTopLeft.y))
    )
    context.fill(
      polygon([.zero, backTopLeft, backBottomLeft, CGPoint(x: 0, y: height)]),
      with: .linearGradient(Gradient(colors: [Color(red: 0.094, green: 0.071, blue: 0.353), Color(red: 0.173, green: 0.129, blue: 0.573)]), startPoint: .zero, endPoint: CGPoint(x: backTopLeft.x, y: 0))
    )
    context.fill(
      polygon([CGPoint(x: width, y: 0), backTopRight, backBottomRight, CGPoint(x: width, y: height)]),
      with: .linearGradient(Gradient(colors: [Color(red: 0.188, green: 0.145, blue: 0.604), Color(red: 0.09, green: 0.067, blue: 0.353)]), startPoint: CGPoint(x: backTopRight.x, y: 0), endPoint: CGPoint(x: width, y: 0))
    )
    context.fill(
      polygon([backBottomLeft, backBottomRight, CGPoint(x: width, y: height), CGPoint(x: 0, y: height)]),
      with: .linearGradient(Gradient(colors: [Color(red: 0.169, green: 0.125, blue: 0.533), Color(red: 0.075, green: 0.055, blue: 0.282)]), startPoint: CGPoint(x: 0, y: backBottomLeft.y), endPoint: CGPoint(x: 0, y: height))
    )
    context.fill(
      Path(art.rect(90, 92, 330, 300)),
      with: .linearGradient(Gradient(colors: [Color(red: 0.267, green: 0.212, blue: 0.675), Color(red: 0.204, green: 0.157, blue: 0.612)]), startPoint: backTopLeft, endPoint: backBottomLeft)
    )
    context.fill(Path(art.rect(90, 386, 330, 6)), with: .color(LabColor.shadow.opacity(0.5)))

    for x in [92.0, 338.0] {
      context.drawLayer { layer in
        layer.addFilter(.blur(radius: 13 * art.scale))
        layer.fill(Path(ellipseIn: art.rect(x, 190, 80, 110)), with: .color(LabColor.label.opacity(0.1)))
      }
      context.fill(Path(roundedRect: art.rect(x + 38, 242, 4, 14), cornerRadius: 2), with: .color(LabColor.secondaryInk.opacity(0.5)))
      context.drawLayer { layer in
        layer.addFilter(.shadow(color: LabColor.label.opacity(0.9), radius: 8 * art.scale))
        layer.fill(Path(ellipseIn: art.rect(x + 34, 226, 12, 16)), with: .color(LabColor.softLight))
      }
    }

    context.drawLayer { layer in
      layer.addFilter(.blur(radius: 20 * art.scale))
      layer.fill(Path(ellipseIn: art.rect(45, 420, 420, 200)), with: .color(LabColor.label.opacity(0.08)))
    }

    let circle = art.rect(85, 450, 340, 106)
    context.fill(Path(ellipseIn: circle), with: .radialGradient(
      Gradient(colors: [LabColor.floorInner.opacity(0.35), LabColor.floorOuter.opacity(0.08)]),
      center: CGPoint(x: circle.midX, y: circle.midY),
      startRadius: 0,
      endRadius: circle.width / 2
    ))
    context.stroke(
      Path(ellipseIn: circle),
      with: .color(LabColor.sceneLabelInk.opacity(0.45)),
      style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 4])
    )
  }

  private func drawMirrors(_ art: RoomArt, in context: inout GraphicsContext) {
    let quads = art.mirrorQuads
    for (index, quad) in [quads.left, quads.right].enumerated() {
      let shape = polygon(quad)
      context.stroke(shape, with: .color(LabColor.shadow.opacity(0.9)), style: StrokeStyle(lineWidth: 9 * art.scale, lineJoin: .round))
      let outer = quad[1]
      let hinge = quad[0]
      context.drawLayer { layer in
        layer.addFilter(.shadow(color: LabColor.mirrorGlow.opacity(0.55), radius: 6 * art.scale))
        layer.fill(shape, with: .linearGradient(
          Gradient(colors: [Color(red: 0.549, green: 0.482, blue: 0.941).opacity(0.55), Color(red: 0.275, green: 0.192, blue: 0.659).opacity(0.55)]),
          startPoint: CGPoint(x: outer.x, y: 0),
          endPoint: CGPoint(x: hinge.x, y: 0)
        ))
      }
      context.stroke(shape, with: .color(LabColor.glassFace.opacity(0.85)), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

      let sheen = index == 0
        ? polygon([art.point(160, 340), art.point(200, 331), art.point(164, 420)])
        : polygon([art.point(310, 331), art.point(350, 340), art.point(346, 372)])
      context.fill(sheen, with: .color(.white.opacity(index == 0 ? 0.14 : 0.1)))
    }

    var hinge = Path()
    hinge.move(to: art.point(255, 296))
    hinge.addLine(to: art.point(255, 474))
    context.drawLayer { layer in
      layer.addFilter(.shadow(color: LabColor.mirrorGlow.opacity(0.5), radius: 13 * art.scale))
      layer.addFilter(.shadow(color: LabColor.mirrorGlow.opacity(0.9), radius: 5 * art.scale))
      layer.stroke(hinge, with: .color(LabColor.secondaryInk.opacity(0.95)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }
  }

  private func polygon(_ points: [CGPoint]) -> Path {
    var path = Path()
    path.addLines(points)
    path.closeSubpath()
    return path
  }
}

/// Maps the design’s half-screen room artwork into a frame, keeping its proportions.
struct RoomArt {
  static let designSize = CGSize(width: 475, height: 669)

  var frame: CGRect

  var scale: CGFloat {
    guard frame.width > 0, frame.height > 0 else { return 1 }
    return min(frame.width / Self.designSize.width, frame.height / Self.designSize.height)
  }

  private var origin: CGPoint {
    CGPoint(
      x: frame.minX + (frame.width - Self.designSize.width * scale) / 2,
      y: frame.minY + (frame.height - Self.designSize.height * scale) / 2
    )
  }

  func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
  }

  func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
    CGRect(origin: point(x, y), size: CGSize(width: width * scale, height: height * scale))
  }

  /// Each mirror as hinge top, outer top, outer bottom, hinge bottom.
  var mirrorQuads: (left: [CGPoint], right: [CGPoint]) {
    (
      [point(255, 296), point(138, 322), point(138, 526), point(255, 474)],
      [point(255, 296), point(372, 322), point(372, 526), point(255, 474)]
    )
  }
}
