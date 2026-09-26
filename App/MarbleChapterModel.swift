import Foundation

struct MarbleChapterModel {
  enum TrialOutcome {
    case short
    case long
    case target
  }

  enum MotionPhase {
    case ready
    case ramp
    case flat
    case stopped
  }

  static let rampEndFraction = 0.38
  static let targetFraction = 0.735
  static let targetTolerance = 0.031

  // DeviceHinge reports the opening angle: 180° open and 0° closed.
  // The experiment uses the complementary fold angle requested by the chapter.
  var hingeDegrees: Double?
  var friction = 0.4
  var gravity = 1.0
  var mass = 60.0
  private(set) var phase: MotionPhase = .ready
  private(set) var rampProgress = 0.0
  private(set) var flatDistance = 0.0
  private(set) var speed = 0.0
  private(set) var rotation = 0.0
  private(set) var lastOutcome: TrialOutcome?
  private(set) var fireflyAwake = false

  var rampDegrees: Double { 54 * tanh((hingeDegrees ?? 0) / 95) }
  var isRolling: Bool { phase == .ramp || phase == .flat }
  var canRoll: Bool { hingeDegrees != nil && !isRolling && !fireflyAwake }
  var displayedFlatDistance: Double { 0.65 * tanh(flatDistance / 0.65) }
  var ballFraction: Double {
    if phase == .ramp || phase == .ready { return Self.rampEndFraction * rampProgress }
    return Self.rampEndFraction + displayedFlatDistance
  }

  static func normalizedFoldAngle(fromRawOpeningAngle raw: Double) -> Double {
    min(180, max(0, 180 - raw))
  }

  mutating func updateHinge(rawOpeningAngle: Double?) {
    let normalized = rawOpeningAngle.map(Self.normalizedFoldAngle(fromRawOpeningAngle:))
    let changed = switch (hingeDegrees, normalized) {
    case let (old?, new?): abs(old - new) > 0.05
    case (nil, nil): false
    default: true
    }
    hingeDegrees = normalized
    if changed && phase == .stopped && !fireflyAwake {
      resetBall()
    }
  }

  mutating func startTrial() {
    guard canRoll else { return }
    rampProgress = 0
    flatDistance = 0
    speed = 0
    rotation = 0
    lastOutcome = nil
    phase = .ramp
  }

  mutating func advance(by elapsed: TimeInterval) {
    guard isRolling else { return }
    let dt = min(0.05, max(0, elapsed))
    guard dt > 0 else { return }

    if phase == .ramp {
      let slope = sin(rampDegrees * .pi / 180)
      let acceleration = (0.06 + 1.6 * slope) * gravity
      let travel = speed * dt + 0.5 * acceleration * dt * dt
      rampProgress = min(1, rampProgress + travel)
      speed += acceleration * dt
      rotation += travel * 7
      if rampProgress >= 1 {
        phase = .flat
        speed *= 0.36
      }
    } else {
      let deceleration = 0.15 + 0.32 * friction
      let nextSpeed = max(0, speed - deceleration * dt)
      let travel = (speed + nextSpeed) * 0.5 * dt
      flatDistance += travel
      rotation += travel * 19
      speed = nextSpeed
      if speed <= 0 {
        phase = .stopped
        let difference = ballFraction - Self.targetFraction
        lastOutcome = abs(difference) <= Self.targetTolerance
          ? .target : (difference < 0 ? .short : .long)
        fireflyAwake = lastOutcome == .target
      }
    }
  }

  private mutating func resetBall() {
    phase = .ready
    rampProgress = 0
    flatDistance = 0
    speed = 0
    rotation = 0
    lastOutcome = nil
  }
}
