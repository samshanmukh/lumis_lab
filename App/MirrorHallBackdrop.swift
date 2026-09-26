import SwiftUI

/// The dark gallery behind the mirror scene. When the phone opens like a book,
/// each half keeps a faint mirror-glass edge and a corner glint, and the fold glows.
struct MirrorHallBackdrop: View {
  var center: CGPoint
  var radiusX: CGFloat
  var foldX: CGFloat?
  var foldGlow: Double = 0

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      ZStack(alignment: .topLeading) {
        LabBackdrop(showsFireflies: false)

        Canvas { context, size in
          let scale = radiusX / 300
          let gallery = CGRect(x: center.x - 560 * scale, y: -360 * scale, width: 1120 * scale, height: 600 * scale)
          context.drawLayer { layer in
            layer.addFilter(.blur(radius: 35 * scale))
            layer.fill(Path(ellipseIn: gallery), with: .color(LabColor.mirrorGlow.opacity(0.12)))
          }

          var cone = Path()
          cone.move(to: CGPoint(x: center.x - radiusX * 0.233, y: 0))
          cone.addLine(to: CGPoint(x: center.x + radiusX * 0.233, y: 0))
          cone.addLine(to: CGPoint(x: center.x + radiusX, y: center.y))
          cone.addLine(to: CGPoint(x: center.x - radiusX, y: center.y))
          cone.closeSubpath()
          context.drawLayer { layer in
            layer.addFilter(.blur(radius: 15 * scale))
            layer.fill(cone, with: .linearGradient(
              Gradient(colors: [LabColor.glassFace.opacity(0.07), LabColor.glassFace.opacity(0)]),
              startPoint: CGPoint(x: center.x, y: 0),
              endPoint: CGPoint(x: center.x, y: center.y)
            ))
          }
        }

        if let foldX {
          halves(size: size, foldX: foldX)
        }
      }
    }
    .accessibilityHidden(true)
  }

  private func halves(size: CGSize, foldX: CGFloat) -> some View {
    ZStack(alignment: .topLeading) {
      glassEdge(width: foldX, height: size.height)
      glassEdge(width: size.width - foldX, height: size.height)
        .offset(x: foldX)

      glint(leading: true)
      glint(leading: false)
        .offset(x: size.width - 170)

      Rectangle()
        .fill(LinearGradient(
          colors: [.white.opacity(0), .white.opacity(0.04 + 0.2 * foldGlow), .white.opacity(0)],
          startPoint: .leading,
          endPoint: .trailing
        ))
        .frame(width: 44, height: size.height)
        .offset(x: foldX - 22)
      Rectangle()
        .fill(.white.opacity(0.07 + 0.6 * foldGlow))
        .frame(width: 1, height: size.height)
        .shadow(color: LabColor.mirrorGlow.opacity(foldGlow), radius: 10)
        .offset(x: foldX - 0.5)
    }
  }

  private func glassEdge(width: CGFloat, height: CGFloat) -> some View {
    Rectangle()
      .strokeBorder(LabColor.mirrorGlow.opacity(0.35), lineWidth: 14)
      .blur(radius: 18)
      .frame(width: width, height: height)
      .clipped()
  }

  private func glint(leading: Bool) -> some View {
    Path { path in
      if leading {
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 170, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 230))
      } else {
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 170, y: 0))
        path.addLine(to: CGPoint(x: 170, y: 230))
      }
      path.closeSubpath()
    }
    .fill(LinearGradient(
      colors: [.white.opacity(0.07), .white.opacity(0)],
      startPoint: leading ? .topLeading : .topTrailing,
      endPoint: leading ? .center : .center
    ))
    .frame(width: 170, height: 230)
  }
}
