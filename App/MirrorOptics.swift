import Foundation

/// How many Lumis two mirrors make at an angle, and where each one stands.
enum MirrorOptics {
  static let neatAngles: [Double] = [180, 120, 90, 72, 60, 45]
  static let tolerance: Double = 2
  static let range: ClosedRange<Double> = 40...180

  static func clamped(_ angle: Double) -> Double {
    min(range.upperBound, max(range.lowerBound, angle))
  }

  static func neatAngle(near angle: Double) -> Double? {
    neatAngles.first { abs($0 - angle) <= tolerance }
  }

  /// Whole Lumis in the circle: exact at the neat angles, rounded down between them.
  static func count(for angle: Double) -> Int {
    if let neat = neatAngle(near: angle) { return Int((360 / neat).rounded()) }
    return Int((360 / clamped(angle)).rounded(.down))
  }

  /// The count the challenge says out loud. Past the goal it rounds up, so an overshoot reads as “more”.
  static func challengeCount(for angle: Double, goal: Double) -> Int {
    if let neat = neatAngle(near: angle) { return Int((360 / neat).rounded()) }
    let exact = 360 / clamped(angle)
    return Int(angle < goal ? exact.rounded(.up) : exact.rounded(.down))
  }

  /// Every Lumi, real one first, then reflections alternating sides.
  /// Between neat angles the next Lumi fades in as a guide only.
  static func placements(for angle: Double) -> [LumiPlacement] {
    let theta = clamped(angle)
    let exact = 360 / theta
    let whole: Int
    var guideOpacity = 0.0
    if let neat = neatAngle(near: theta) {
      whole = Int((360 / neat).rounded())
    } else {
      whole = Int(exact.rounded(.down))
      guideOpacity = (exact - Double(whole)) * 0.8
    }
    let total = whole + (guideOpacity > 0.03 ? 1 : 0)

    var result = [LumiPlacement(index: 0, degrees: 0, bounces: 0, opacity: 1)]
    var bounces = 1
    while result.count < total {
      for side in [1.0, -1.0] where result.count < total {
        let index = result.count
        result.append(LumiPlacement(
          index: index,
          degrees: side * Double(bounces) * theta,
          bounces: bounces,
          opacity: index < whole ? 1 : guideOpacity
        ))
      }
      bounces += 1
    }
    return result
  }

  /// Angles of the dotted slice edges: where the mirrors’ reflections sit.
  static func sliceEdges(for angle: Double) -> [Double] {
    let theta = clamped(angle)
    var edges: [Double] = []
    var offset = theta / 2 + theta
    while offset <= 180.5 {
      edges.append(offset)
      if offset < 179.5 { edges.append(-offset) }
      offset += theta
    }
    return edges
  }
}

struct LumiPlacement: Identifiable {
  var index: Int
  /// Position around the circle: 0 is the front, positive is to the viewer’s right.
  var degrees: Double
  /// Reflections it took to make this Lumi; 0 is the real one.
  var bounces: Int
  var opacity: Double

  var id: Int { index }
  var isReal: Bool { bounces == 0 }
  /// An odd number of reflections flips Lumi, so the curl swaps sides.
  var isMirrored: Bool { bounces % 2 == 1 }
  var depth: Double { cos(degrees * .pi / 180) }
}
