import Foundation

/// Light leaving the Glass Pond: magic glass (n = 1.5) under air (n = 1).
/// The teaching model is glass to air, so the tipping point is 41.8°, not water's 48.6°.
enum GlassOptics {
  static let glassIndex = 1.5
  /// asin(1 ÷ 1.5) ≈ 41.81°. Past it no light gets out; children see it as 42°.
  static let criticalAngle = asin(1 / glassIndex) * 180 / .pi
  static let tiltRange: ClosedRange<Double> = 0...60
  /// Where the light starts to only skim the surface.
  static let skimStart = 39.0
  /// Where the challenge says “Almost”.
  static let almostStart = 38.0
  /// Labels and haptics only fall back once the tilt is this far below a line, so they don’t flicker.
  static let hysteresis = 0.5
  /// A reflection is never drawn fainter than this, so it stays visible.
  static let minimumDrawnShare = 0.12

  /// tilt = clamp((hinge − 70°) × 2 ÷ 3, 0°, 60°).
  static func tilt(forHinge angle: Double) -> Double {
    clamped((angle - 70) * 2 / 3)
  }

  /// The hinge angle that gives a tilt, so the dial drives the same input as the hinge.
  static func hinge(forTilt tilt: Double) -> Double {
    70 + clamped(tilt) * 3 / 2
  }

  static func clamped(_ tilt: Double) -> Double {
    min(tiltRange.upperBound, max(tiltRange.lowerBound, tilt))
  }

  /// The angle from straight up at which light leaves into the air, or nil once it can’t leave.
  /// Past the critical angle asin has no real value, so it is never evaluated there.
  static func airAngle(forTilt tilt: Double) -> Double? {
    let sine = glassIndex * sin(tilt * .pi / 180)
    guard sine < 1 else { return nil }
    return asin(sine) * 180 / .pi
  }

  /// The share of light the surface bounces back into the glass (Fresnel, unpolarized):
  /// about 4% straight up, 25% at 40°, all of it from 41.8°.
  static func reflectance(forTilt tilt: Double) -> Double {
    let incidence = tilt * .pi / 180
    let sine = glassIndex * sin(incidence)
    guard sine < 1 else { return 1 }
    let cosIn = cos(incidence)
    let cosOut = cos(asin(sine))
    let perpendicular = pow((glassIndex * cosIn - cosOut) / (glassIndex * cosIn + cosOut), 2)
    let parallel = pow((glassIndex * cosOut - cosIn) / (glassIndex * cosOut + cosIn), 2)
    return min(1, (perpendicular + parallel) / 2)
  }

  static func drawnReflection(forTilt tilt: Double) -> Double {
    max(minimumDrawnShare, reflectance(forTilt: tilt))
  }

  static func isStuck(_ tilt: Double) -> Bool { tilt >= criticalAngle }

  /// What the light does at the pond’s surface.
  static func light(forTilt tilt: Double) -> PondLight {
    if tilt >= criticalAngle { return .stuck }
    if tilt >= skimStart { return .skims }
    return .out
  }
}

enum PondLight: Int, Comparable {
  case out
  case skims
  case stuck

  static func < (lhs: PondLight, rhs: PondLight) -> Bool { lhs.rawValue < rhs.rawValue }

  var sceneValue: String {
    switch self {
    case .out: "Light leaves the pond, bent"
    case .skims: "Light skims the surface"
    case .stuck: "Light is stuck, bouncing back inside"
    }
  }
}

/// Which side of each line a value is on. It crosses a line upward at the line itself and
/// only falls back once it is `margin` below it, so a wobbling hinge can’t make it flicker.
struct ZoneTracker {
  let lines: [Double]
  let margin: Double
  private(set) var zone: Int

  init(lines: [Double], margin: Double = GlassOptics.hysteresis, value: Double) {
    self.lines = lines
    self.margin = margin
    zone = lines.filter { value >= $0 }.count
  }

  /// Returns true when the zone changed.
  @discardableResult
  mutating func update(_ value: Double) -> Bool {
    let reached = lines.filter { value >= $0 }.count
    let held = lines.filter { value >= $0 - margin }.count
    let next = reached > zone ? reached : min(zone, held)
    guard next != zone else { return false }
    zone = next
    return true
  }
}
