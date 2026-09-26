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

  /// The Marble Ramp’s tilt: in laptop pose it’s the upright screen’s own tilt.
  var rampAngle: Double { min(Self.rampRange.upperBound, max(Self.rampRange.lowerBound, 180 - angle)) }
  static let rampRange: ClosedRange<Double> = 15...50

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
    source = .hinge
    withAnimation(LabMotion.hinge) {
      angle = min(180, max(0, hinge.angle.degrees))
    }
  }

  func setRampAngle(_ ramp: Double, animation: Animation = LabMotion.hinge) {
    setDialAngle(180 - min(Self.rampRange.upperBound, max(Self.rampRange.lowerBound, ramp)), animation: animation)
  }

  func setDialAngle(_ value: Double, animation: Animation = LabMotion.hinge) {
    source = .dial
    withAnimation(animation) {
      angle = min(180, max(40, value))
    }
  }
}
