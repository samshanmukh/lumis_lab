import Foundation

enum QuizRamp: String, CaseIterable, Identifiable {
  case gentle
  case steep

  var id: String { rawValue }
  var angle: Double { self == .gentle ? 22 : 46 }
  var title: String { self == .gentle ? "Gentle ramp" : "Steep ramp" }
  var heightLabel: String { self == .gentle ? "starts lower" : "starts higher" }

  /// Both ramps are the same length with the marble at the top, so the steep one starts higher.
  var track: MarbleTrack { MarbleTrack(angle: angle, start: .top) }
}

struct MarbleQuizModel {
  /// The steep ramp starts higher, so its marble rolls farther.
  static let answer: QuizRamp = .steep

  var selected: QuizRamp?
  /// Both marbles once a ramp is picked: the pick rolls first, the other a second later.
  private(set) var marbles: [RollingMarble] = []
  var finished = false

  var isPlaying: Bool { selected != nil && !finished }
  var pickedRight: Bool { selected == Self.answer }

  /// Seconds from now until both marbles have stopped.
  var completionDelay: TimeInterval? {
    marbles.map { $0.startedAt.addingTimeInterval($0.plan.duration) }.max()?.timeIntervalSinceNow
  }

  mutating func select(_ ramp: QuizRamp) {
    guard selected == nil else { return }
    selected = ramp
    let firstStart = Date.now
    let other: QuizRamp = ramp == .gentle ? .steep : .gentle
    marbles = [
      RollingMarble(track: ramp.track, plan: ramp.track.plan(), startedAt: firstStart),
      RollingMarble(track: other.track, plan: other.track.plan(), startedAt: firstStart.addingTimeInterval(1))
    ]
  }
}
