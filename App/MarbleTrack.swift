import Foundation
import CoreGraphics

/// The Marble Ramp in the design’s 669 × 476 garden: the path is at y 418 and every ramp,
/// whatever its tilt, meets the path at the same foot. Motion comes from the drop, not a
/// physics engine: a rolling ball reaches √(10/7·g·h) at the bottom, and the path stops it
/// 1.36 × h past the foot, so every roll from the star stops at the same flag.
enum MarbleGarden {
  static let size = CGSize(width: 669, height: 476)
  static let groundY: CGFloat = 418
  static let foot = CGPoint(x: 330, y: 418)
  static let rampLength: CGFloat = 320
  /// The star line: the same start height for every roll in Try it.
  static let starHeight: CGFloat = 70
  /// The ramp curves into the path over this much track on each side of the foot.
  static let curve: CGFloat = 44
  static let stopFactor: CGFloat = 1.36
  static let cupX: CGFloat = 612
  static let marbleRadius: CGFloat = 12
  /// From the top, the marble sits this far down the ramp so it rests on it.
  static let topInset: CGFloat = 16
  /// Gravity in points per second², tuned so a roll takes 1–2.5 s.
  static let gravity: CGFloat = 1200
  /// A stop within this far of the cup is “almost”.
  static let nearMiss: CGFloat = 45
}

enum MarbleStart: Equatable {
  /// On the star line, the same height every time.
  case star
  /// At the very top of the ramp.
  case top
}

/// One ramp at one tilt, with where the marble starts and where it stops.
struct MarbleTrack: Equatable {
  var angle: Double
  var start: MarbleStart

  private var radians: Double { angle * .pi / 180 }
  /// Up the ramp, from the foot toward the top.
  var up: CGVector { CGVector(dx: -cos(radians), dy: -sin(radians)) }

  func pointOnRamp(_ distance: CGFloat) -> CGPoint {
    let foot = MarbleGarden.foot
    return CGPoint(x: foot.x + up.dx * distance, y: foot.y + up.dy * distance)
  }

  var top: CGPoint { pointOnRamp(MarbleGarden.rampLength) }
  var curveStart: CGPoint { pointOnRamp(MarbleGarden.curve) }
  var curveEnd: CGPoint { CGPoint(x: MarbleGarden.foot.x + MarbleGarden.curve, y: MarbleGarden.groundY) }

  /// How far up the ramp the marble starts.
  var startDistance: CGFloat {
    switch start {
    case .star: MarbleGarden.starHeight / CGFloat(sin(radians))
    case .top: MarbleGarden.rampLength - MarbleGarden.topInset
    }
  }

  var startHeight: CGFloat { startDistance * CGFloat(sin(radians)) }

  /// Where the path would stop the marble.
  var stopX: CGFloat { MarbleGarden.foot.x + MarbleGarden.stopFactor * startHeight }

  /// The flower cup catches it, so steeper than needed still wins.
  var reachesCup: Bool { stopX >= MarbleGarden.cupX - 2 }

  var restX: CGFloat { min(stopX, MarbleGarden.cupX) }

  /// The ramp as drawn: straight from the top, curving into the path.
  func path(extendingTo pathEnd: CGFloat? = nil) -> CGPath {
    let path = CGMutablePath()
    path.move(to: top)
    path.addLine(to: curveStart)
    path.addQuadCurve(to: curveEnd, control: MarbleGarden.foot)
    if let pathEnd { path.addLine(to: CGPoint(x: pathEnd, y: MarbleGarden.groundY)) }
    return path
  }

  /// Where the marble’s center sits when it rests at a distance up the ramp.
  func marbleCenter(onRampAt distance: CGFloat) -> CGPoint {
    let surface = pointOnRamp(distance)
    let normal = CGVector(dx: sin(radians), dy: -cos(radians))
    return CGPoint(x: surface.x + normal.dx * MarbleGarden.marbleRadius, y: surface.y + normal.dy * MarbleGarden.marbleRadius)
  }

  var startCenter: CGPoint { marbleCenter(onRampAt: startDistance) }

  /// The center of a marble of any size a fraction of the way down, from where it starts to where
  /// the curve meets the path, measured along the track.
  func descentCenter(_ fraction: Double, radius: CGFloat = MarbleGarden.marbleRadius) -> CGPoint {
    var surface = [pointOnRamp(startDistance), curveStart]
    let p0 = curveStart, p1 = MarbleGarden.foot, p2 = curveEnd
    for step in 1...24 {
      let t = CGFloat(step) / 24
      let a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, c = t * t
      surface.append(CGPoint(x: a * p0.x + b * p1.x + c * p2.x, y: a * p0.y + b * p1.y + c * p2.y))
    }
    let lengths = zip(surface, surface.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
    var remaining = lengths.reduce(0, +) * CGFloat(min(1, max(0, fraction)))
    for index in lengths.indices {
      let start = surface[index], end = surface[index + 1]
      let length = max(0.0001, lengths[index])
      guard remaining > length, index < lengths.count - 1 else {
        let t = min(1, remaining / length)
        let point = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
        return CGPoint(x: point.x + (end.y - start.y) / length * radius, y: point.y - (end.x - start.x) / length * radius)
      }
      remaining -= length
    }
    return CGPoint(x: curveEnd.x, y: curveEnd.y - radius)
  }

  var restCenter: CGPoint {
    CGPoint(x: restX, y: MarbleGarden.groundY - MarbleGarden.marbleRadius + (reachesCup ? 4 : 0))
  }

  func plan() -> RollPlan { RollPlan(track: self) }
}

/// A roll worked out ahead of time: the marble’s center and spin at each moment.
struct RollPlan: Equatable {
  private(set) var times: [Double] = []
  private(set) var centers: [CGPoint] = []
  private(set) var travel: [CGFloat] = []

  var duration: Double { times.last ?? 0 }

  init(track: MarbleTrack) {
    let g = MarbleGarden.gravity
    let radius = MarbleGarden.marbleRadius
    let startHeight = track.startHeight
    let bottomSpeed = sqrt(10 / 7 * g * startHeight)

    // Descent: straight part, then the curve, sampled every point or so.
    var surface: [CGPoint] = []
    let straight = max(0, track.startDistance - MarbleGarden.curve)
    let straightSteps = max(1, Int(straight))
    for step in 0...straightSteps {
      surface.append(track.pointOnRamp(track.startDistance - straight * CGFloat(step) / CGFloat(straightSteps)))
    }
    let curveSteps = 60
    let p0 = track.curveStart, p1 = MarbleGarden.foot, p2 = track.curveEnd
    for step in 1...curveSteps {
      let t = CGFloat(step) / CGFloat(curveSteps)
      let a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, c = t * t
      surface.append(CGPoint(x: a * p0.x + b * p1.x + c * p2.x, y: a * p0.y + b * p1.y + c * p2.y))
    }

    var time = 0.0
    var distance: CGFloat = 0
    for index in surface.indices {
      let point = surface[index]
      var normal = CGVector(dx: 0, dy: -1)
      if index + 1 < surface.count {
        let next = surface[index + 1]
        let length = max(0.0001, hypot(next.x - point.x, next.y - point.y))
        normal = CGVector(dx: (next.y - point.y) / length, dy: -(next.x - point.x) / length)
      } else if index > 0 {
        let previous = surface[index - 1]
        let length = max(0.0001, hypot(point.x - previous.x, point.y - previous.y))
        normal = CGVector(dx: (point.y - previous.y) / length, dy: -(point.x - previous.x) / length)
      }
      if index > 0 {
        let previous = surface[index - 1]
        let step = hypot(point.x - previous.x, point.y - previous.y)
        let midHeight = MarbleGarden.groundY - (point.y + previous.y) / 2
        let speed = max(8, sqrt(max(0, 10 / 7 * g * (startHeight - midHeight))))
        time += Double(step / speed)
        distance += step
      }
      times.append(time)
      centers.append(CGPoint(x: point.x + normal.dx * radius, y: point.y + normal.dy * radius))
      travel.append(distance)
    }

    // The path: slow down evenly and stop at the rule’s spot, or drop into the cup.
    let groundStart = track.curveEnd.x
    let slowing = bottomSpeed * bottomSpeed / (2 * max(1, track.stopX - groundStart))
    let groundLength = track.restX - groundStart
    let groundSteps = max(1, Int(groundLength / 2))
    for step in 1...groundSteps {
      let along = groundLength * CGFloat(step) / CGFloat(groundSteps)
      let speedSquared = max(0, bottomSpeed * bottomSpeed - 2 * slowing * along)
      let elapsed = (bottomSpeed - sqrt(speedSquared)) / slowing
      times.append(time + Double(elapsed))
      centers.append(CGPoint(x: groundStart + along, y: MarbleGarden.groundY - radius))
      travel.append(distance + along)
    }
    if track.reachesCup, let last = centers.last, let lastTime = times.last, let lastTravel = travel.last {
      times.append(lastTime + 0.18)
      centers.append(CGPoint(x: last.x, y: last.y + 4))
      travel.append(lastTravel + 4)
    }
  }

  /// The marble’s center and how far it has rolled, at a moment in the roll.
  func sample(at elapsed: Double) -> (center: CGPoint, travel: CGFloat) {
    guard let first = times.first, elapsed > first else { return (centers.first ?? .zero, 0) }
    guard elapsed < duration else { return (centers.last ?? .zero, travel.last ?? 0) }
    var low = 0, high = times.count - 1
    while high - low > 1 {
      let mid = (low + high) / 2
      if times[mid] <= elapsed { low = mid } else { high = mid }
    }
    let span = max(0.000_001, times[high] - times[low])
    let t = CGFloat((elapsed - times[low]) / span)
    let a = centers[low], b = centers[high]
    return (CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t), travel[low] + (travel[high] - travel[low]) * t)
  }

  /// Faint dots left along the way, one every 19 pt of track.
  var trail: [CGPoint] {
    var dots: [CGPoint] = []
    var next: CGFloat = 19
    for index in centers.indices where travel[index] >= next {
      dots.append(centers[index])
      next += 19
    }
    return dots
  }
}
