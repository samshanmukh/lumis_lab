import SwiftUI

/// The seeIt move: the two standing mirrors grow and turn to face you until each fills
/// one half of the screen, and their hinge becomes the fold.
struct SeeItOverlay: View {
  var from: (left: [CGPoint], right: [CGPoint])
  var size: CGSize
  var foldX: CGFloat
  var progress: CGFloat
  var glass: Double

  var body: some View {
    let left = [CGPoint(x: foldX, y: 0), .zero, CGPoint(x: 0, y: size.height), CGPoint(x: foldX, y: size.height)]
    let right = [CGPoint(x: foldX, y: 0), CGPoint(x: size.width, y: 0), CGPoint(x: size.width, y: size.height), CGPoint(x: foldX, y: size.height)]

    ZStack {
      pane(from: from.left, to: left, outerOnLeft: true)
      pane(from: from.right, to: right, outerOnLeft: false)

      MorphingQuad(from: [from.left[0], from.left[0], from.left[3], from.left[3]], to: [left[0], left[0], left[3], left[3]], progress: progress)
        .stroke(LabColor.secondaryInk, lineWidth: 2.5)
        .shadow(color: LabColor.mirrorGlow.opacity(0.9), radius: 5)
        .shadow(color: LabColor.mirrorGlow.opacity(0.5), radius: 13)
        .opacity(0.4 + 0.6 * glass)
    }
    .frame(width: size.width, height: size.height)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func pane(from: [CGPoint], to: [CGPoint], outerOnLeft: Bool) -> some View {
    let shape = MorphingQuad(from: from, to: to, progress: progress)
    return shape
      .fill(LinearGradient(
        colors: [Color(red: 0.549, green: 0.482, blue: 0.941).opacity(0.55), Color(red: 0.275, green: 0.192, blue: 0.659).opacity(0.55)],
        startPoint: outerOnLeft ? .leading : .trailing,
        endPoint: outerOnLeft ? .trailing : .leading
      ))
      .opacity(glass)
      .overlay {
        shape.stroke(LabColor.glassFace.opacity(0.85 * glass), lineWidth: 1.5)
      }
  }
}

/// A four-cornered shape that moves each corner from one position to another.
struct MorphingQuad: Shape {
  var from: [CGPoint]
  var to: [CGPoint]
  var progress: CGFloat

  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let points = zip(from, to).map { start, end in
      CGPoint(x: start.x + (end.x - start.x) * progress, y: start.y + (end.y - start.y) * progress)
    }
    path.addLines(points)
    path.closeSubpath()
    return path
  }
}
