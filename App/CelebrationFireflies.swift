import SwiftUI

/// celebrate: fireflies drift in from the edges, circle Lumi, then settle in an arc
/// above the circle, never over a Lumi.
struct CelebrationFireflies: View {
  var center: CGPoint
  var radiusX: CGFloat
  /// Where each firefly settles, relative to the center at a 300 pt radius.
  var settled: [CGSize] = Self.aboveTheCircle
  var finished: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var phase = 0
  @State private var visible = false

  static let aboveTheCircle: [CGSize] = [
    CGSize(width: -230, height: -130), CGSize(width: -150, height: -170), CGSize(width: -75, height: -200),
    CGSize(width: 80, height: -192), CGSize(width: 160, height: -162), CGSize(width: 235, height: -122)
  ]

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        Color.clear
        ForEach(settled.indices, id: \.self) { index in
          FireflyView(size: 22 * max(0.7, radiusX / 300))
            .position(position(index, in: geometry.size))
            .opacity(visible ? 1 : 0)
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .task { await play() }
  }

  private func position(_ index: Int, in size: CGSize) -> CGPoint {
    let scale = radiusX / 300
    let ringY = radiusX / 3
    switch phase {
    case 0:
      let fromLeft = index % 2 == 0
      return CGPoint(x: fromLeft ? -30 : size.width + 30, y: size.height * (0.15 + 0.12 * CGFloat(index)))
    case 1, 2:
      let turn = phase == 1 ? 0.0 : 70.0
      let degrees = Double(index) * 60 + turn
      let radians = degrees * .pi / 180
      return CGPoint(
        x: center.x + radiusX * 0.95 * CGFloat(sin(radians)),
        y: center.y - ringY * 0.4 + ringY * 1.5 * CGFloat(cos(radians))
      )
    default:
      let offset = settled[index]
      return CGPoint(x: center.x + offset.width * scale, y: center.y + offset.height * scale)
    }
  }

  private func play() async {
    if reduceMotion {
      phase = 3
      withAnimation(LabMotion.reduced) { visible = true }
      finished()
      return
    }
    visible = true
    try? await Task.sleep(for: .milliseconds(30))
    withAnimation(.spring(duration: 0.55, bounce: 0.3)) { phase = 1 }
    try? await Task.sleep(for: .milliseconds(500))
    withAnimation(.easeInOut(duration: 0.45)) { phase = 2 }
    try? await Task.sleep(for: .milliseconds(450))
    withAnimation(.spring(duration: 0.65, bounce: 0.3)) { phase = 3 }
    try? await Task.sleep(for: .milliseconds(650))
    finished()
  }
}
