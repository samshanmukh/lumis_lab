import Foundation

struct MarbleTrial {
  static let targetFraction = 0.735
  static let targetTolerance = 0.031

  var id = UUID()
  var rampDegrees: Double
  var startedAt: Date

  var slopeFraction: Double {
    (rampDegrees - 14) / 40
  }

  var stoppingFraction: Double {
    0.38 + 0.15 + 0.44 * slopeFraction
  }

  var rampDuration: TimeInterval {
    2.15 - slopeFraction
  }

  var flatDuration: TimeInterval {
    1.45 + 1.2 * slopeFraction
  }

  var totalDuration: TimeInterval {
    rampDuration + flatDuration
  }

  func progress(at date: Date) -> MarbleMotion {
    let elapsed = max(0, date.timeIntervalSince(startedAt))
    if elapsed <= rampDuration {
      let fraction = min(1, elapsed / rampDuration)
      return MarbleMotion(
        distanceFraction: fraction * fraction,
        onRamp: true,
        rotation: fraction * fraction * 7
      )
    }

    let fraction = min(1, (elapsed - rampDuration) / flatDuration)
    let easeOut = 1 - (1 - fraction) * (1 - fraction)
    return MarbleMotion(
      distanceFraction: easeOut,
      onRamp: false,
      rotation: 7 + easeOut * (8 + 9 * slopeFraction)
    )
  }
}

struct MarbleMotion {
  var distanceFraction: Double
  var onRamp: Bool
  var rotation: Double
}
