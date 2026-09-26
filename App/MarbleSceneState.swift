import Foundation
import CoreGraphics

/// Everything the Marble Ramp scene draws on one step, in the garden’s design coordinates.
struct MarbleSceneState: Equatable {
  var ramps: [RampMark] = []
  var restingMarbles: [CGPoint] = []
  var rolling: [RollingMarble] = []
  var trail: [CGPoint] = []
  var flags: [FlagMark] = []
  var showsStarLine = true
  var callouts: MarbleCallouts = .none
  var flowerOpen = false
  var lumiMood: LumiMood = .wonder
  var labelPulse = 0
  var accessibilityValue = ""
}

/// A ramp to draw. The earlier ramp stays as a faint ghost so both can be compared.
struct RampMark: Equatable {
  var track: MarbleTrack
  var isGhost = false
}

/// Where rolls stopped. Rolls that stop at the same spot stack their labels, newest on top.
struct FlagMark: Identifiable, Equatable {
  var x: CGFloat
  var labels: [String]
  var isNewest: Bool
  var landedAt: Date

  var id: Int { Int(x.rounded()) }

  /// Groups rolls by where they stopped.
  static func marks(for rolls: [MarbleRoll]) -> [FlagMark] {
    var marks: [FlagMark] = []
    for roll in rolls {
      let x = roll.track.restX
      let label = "\(Int(roll.track.angle))°"
      if let existing = marks.firstIndex(where: { abs($0.x - x) < 4 }) {
        marks[existing].labels.removeAll { $0 == label }
        marks[existing].labels.insert(label, at: 0)
        marks[existing].landedAt = roll.landedAt
      } else {
        marks.append(FlagMark(x: x, labels: [label], isNewest: false, landedAt: roll.landedAt))
      }
    }
    if let last = rolls.last, let newest = marks.firstIndex(where: { abs($0.x - last.track.restX) < 4 }) {
      marks[newest].isNewest = true
    }
    return marks
  }
}

/// The Why beats’ labels on the scene.
enum MarbleCallouts: Equatable {
  case none
  /// Beat a: two dashed drops from the star line, “same height”.
  case sameHeight
  /// Beat b: “steep: quick”, “gentle: slow” and one “same speed” arrow.
  case quickSlow
  /// Beat c: “same drop” and “same speed”.
  case sameDrop
}
