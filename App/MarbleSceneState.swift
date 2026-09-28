import Foundation
import CoreGraphics

/// Everything the Marble Ramp scene draws on one step, in the garden’s design coordinates.
struct MarbleSceneState: Equatable {
  var ramps: [RampMark] = []
  var restingMarbles: [CGPoint] = []
  /// A heavier marble in the chapter’s lab looks bigger; it rolls the same.
  var marbleRadius: CGFloat = MarbleGarden.marbleRadius
  var rolling: [RollingMarble] = []
  var trail: [CGPoint] = []
  var flags: [FlagMark] = []
  var showsStarLine = true
  var callouts: MarbleCallouts = .none
  var flowerOpen = false
  /// With the flower open, the other fireflies gather round it; later they drift off again.
  var firefliesGather = true
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
    marks(for: rolls.map { (x: $0.track.restX, label: "\(Int($0.track.angle))°", landedAt: $0.landedAt) })
  }

  /// Groups stops by where they are, oldest first.
  static func marks(for stops: [(x: CGFloat, label: String, landedAt: Date)]) -> [FlagMark] {
    var marks: [FlagMark] = []
    for stop in stops {
      if let existing = marks.firstIndex(where: { abs($0.x - stop.x) < 4 }) {
        marks[existing].labels.removeAll { $0 == stop.label }
        marks[existing].labels.insert(stop.label, at: 0)
        marks[existing].landedAt = stop.landedAt
      } else {
        marks.append(FlagMark(x: stop.x, labels: [stop.label], isNewest: false, landedAt: stop.landedAt))
      }
    }
    if let last = stops.last, let newest = marks.firstIndex(where: { abs($0.x - last.x) < 4 }) {
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
  /// The chapter’s two ramps from the top: a dashed drop from each start, “starts lower” and
  /// “starts higher”.
  case startHeights
}
