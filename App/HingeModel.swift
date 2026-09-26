import SwiftUI
import Observation

enum HingeSource {
  case hinge
  case dial
}

enum HingeStatus {
  case closed
  case partiallyOpen
  case fullyOpen
}

@Observable
final class HingeModel {
  private(set) var angle: Double = 120
  private(set) var status: HingeStatus = .fullyOpen
  private(set) var source: HingeSource = .dial
  private(set) var deviceAngle: Double?

  var usesDial: Bool { source == .dial || status != .partiallyOpen }
  var mirrorAngle: Double { min(180, max(40, angle)) }

  @available(iOS 27.1, *)
  func receive(_ context: DeviceHingeContext) {
    guard let hinge = context.hinge else {
      deviceAngle = nil
      source = .dial
      return
    }
    if hinge.status == .closed {
      status = .closed
    } else if hinge.status == .fullyOpen {
      status = .fullyOpen
    } else {
      status = .partiallyOpen
    }
    deviceAngle = hinge.angle.degrees
    guard status == .partiallyOpen else {
      source = .dial
      return
    }
    // Handing over from the dial eases the scene to the hinge over 0.3 s: never a jump.
    let handOff = source == .dial
    source = .hinge
    withAnimation(handOff ? .easeInOut(duration: 0.3) : LabMotion.hinge) {
      angle = min(180, max(0, hinge.angle.degrees))
    }
  }

  func setDialAngle(_ value: Double, animation: Animation = LabMotion.hinge) {
    source = .dial
    withAnimation(animation) {
      angle = min(180, max(40, value))
    }
  }
}
