import Foundation

enum QuizRamp: String, CaseIterable, Identifiable {
  case gentle
  case steep

  var id: String { rawValue }
  var angle: Double { self == .gentle ? 22 : 46 }
  var title: String { self == .gentle ? "Gentle ramp" : "Steep ramp" }
  var heightLabel: String { self == .gentle ? "starts lower" : "starts higher" }
}

struct MarbleQuizModel {
  var selected: QuizRamp?
  var gentleTrial: MarbleTrial?
  var steepTrial: MarbleTrial?
  var finished = false

  var isPlaying: Bool { selected != nil && !finished }

  var completionDelay: TimeInterval? {
    guard let gentleTrial, let steepTrial else { return nil }
    return max(
      gentleTrial.startedAt.addingTimeInterval(gentleTrial.totalDuration),
      steepTrial.startedAt.addingTimeInterval(steepTrial.totalDuration)
    ).timeIntervalSinceNow
  }

  mutating func select(_ ramp: QuizRamp) {
    guard selected == nil else { return }
    selected = ramp
    let firstStart = Date.now
    let secondStart = firstStart.addingTimeInterval(1.0)
    gentleTrial = MarbleTrial(
      rampDegrees: QuizRamp.gentle.angle,
      startedAt: ramp == .gentle ? firstStart : secondStart
    )
    steepTrial = MarbleTrial(
      rampDegrees: QuizRamp.steep.angle,
      startedAt: ramp == .steep ? firstStart : secondStart
    )
  }

  func trial(for ramp: QuizRamp) -> MarbleTrial? {
    ramp == .gentle ? gentleTrial : steepTrial
  }
}
