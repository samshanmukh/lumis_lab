import Foundation

struct GlassOptics {
  static let glassIndex = 1.5
  static let airIndex = 1.0
  static let criticalAngle = asin(airIndex / glassIndex) * 180 / .pi

  static func snapshot(at rawAngle: Double) -> PondLightSnapshot {
    let angle = min(max(rawAngle, 0), 60)
    let incident = angle * .pi / 180
    let transmittedSine = glassIndex / airIndex * sin(incident)

    if transmittedSine >= 1 {
      return PondLightSnapshot(
        angle: angle,
        state: .trapped,
        outgoingAngle: nil,
        reflectedFraction: 1
      )
    }

    let transmitted = asin(transmittedSine)
    let cosineIncident = cos(incident)
    let cosineTransmitted = cos(transmitted)
    let s = (glassIndex * cosineIncident - airIndex * cosineTransmitted)
      / (glassIndex * cosineIncident + airIndex * cosineTransmitted)
    let p = (airIndex * cosineIncident - glassIndex * cosineTransmitted)
      / (airIndex * cosineIncident + glassIndex * cosineTransmitted)
    let reflectedFraction = (s * s + p * p) / 2

    return PondLightSnapshot(
      angle: angle,
      state: angle >= 39 ? .skimming : .escaping,
      outgoingAngle: transmitted * 180 / .pi,
      reflectedFraction: reflectedFraction
    )
  }

  static func tilt(forHingeAngle hingeAngle: Double) -> Double {
    min(max((hingeAngle - 70) * 2 / 3, 0), 60)
  }
}

enum PondLightState: Equatable {
  case escaping
  case skimming
  case trapped
}

struct PondLightSnapshot: Equatable {
  var angle: Double
  var state: PondLightState
  var outgoingAngle: Double?
  var reflectedFraction: Double

  var status: String {
    switch state {
    case .escaping: "It gets out."
    case .skimming: "The light skims the surface."
    case .trapped: "Stuck! The light can’t get out."
    }
  }

  var accessibilityDescription: String {
    switch state {
    case .escaping: "Light leaves the pond, bent."
    case .skimming: "Light skims the surface."
    case .trapped: "Light is stuck, bouncing back inside."
    }
  }
}
