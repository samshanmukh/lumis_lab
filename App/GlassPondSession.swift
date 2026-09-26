import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class GlassPondSession {
  var stage: GlassPondStage = .entrance
  var tilt = 25.0
  var inputMode: PondInputMode = .dial
  var hingeAvailable = false
  var prefersDial = false
  var prediction: PondAnswer?
  var checkAnswer: PondAnswer?
  var checkFeedback: String?
  var wrongCheckCount = 0
  var answerRevealed = false
  var explanationBeat = 0
  var checkpointTwoAnswer: VineAnswer?
  var hasSeenEscaping = false
  var hasSeenTrapped = false
  var whatHappenedAvailable = false
  var isShowingSweep = false
  var earnedGuess = false
  var earnedAnswer = false
  var earnedChallenge = false
  var thresholdCrossings = 0
  var wins = 0
  var previouslyCompleted = UserDefaults.standard.bool(forKey: "glassPondCompleted")

  @ObservationIgnored private var sweepTask: Task<Void, Never>?
  @ObservationIgnored private var challengeHoldTask: Task<Void, Never>?

  var snapshot: PondLightSnapshot {
    GlassOptics.snapshot(at: sceneAngle)
  }

  var sceneAngle: Double {
    switch stage {
    case .explanation:
      [25, 41.7, 48][explanationBeat]
    case .checkpointTwo:
      48
    case .solved:
      max(tilt, 50)
    default:
      tilt
    }
  }

  var showsVine: Bool {
    stage == .checkpointTwo || stage == .challenge || stage == .solved
  }

  var progressIndex: Int {
    switch stage {
    case .entrance: 0
    case .prediction: 0
    case .experiment: 1
    case .check: 2
    case .explanation: 3
    case .checkpointTwo: 4
    case .challenge, .solved: 5
    }
  }

  var earnedFireflies: Int {
    [earnedGuess, earnedAnswer, earnedChallenge].filter { $0 }.count
  }

  func enterRoom() {
    stage = .prediction
  }

  func choosePrediction(_ answer: PondAnswer) {
    prediction = answer
    earnedGuess = true
  }

  func startExperiment() {
    stage = .experiment
    hasSeenEscaping = true
    hasSeenTrapped = false
    whatHappenedAvailable = false
    if inputMode == .dial { updateTilt(25) }
  }

  func setDialTilt(_ angle: Double) {
    sweepTask?.cancel()
    sweepTask = nil
    isShowingSweep = false
    prefersDial = true
    inputMode = .dial
    updateTilt(angle)
  }

  func useHinge() {
    guard hingeAvailable else { return }
    prefersDial = false
    inputMode = .hinge
  }

  @available(iOS 27.1, *)
  func receiveHinge(_ context: DeviceHingeContext) {
    guard let hinge = context.hinge, hinge.status == .partiallyOpen else {
      hingeAvailable = false
      inputMode = .dial
      return
    }
    hingeAvailable = true
    guard !prefersDial else { return }
    inputMode = .hinge
    updateTilt(GlassOptics.tilt(forHingeAngle: hinge.angle.degrees))
  }

  func showMe() {
    sweepTask?.cancel()
    isShowingSweep = true
    inputMode = .dial
    prefersDial = true
    sweepTask = Task { @MainActor in
      for step in 0...30 {
        guard !Task.isCancelled else { return }
        updateTilt(20 + Double(step))
        try? await Task.sleep(nanoseconds: 133_000_000)
      }
      whatHappenedAvailable = true
      isShowingSweep = false
      sweepTask = nil
    }
  }

  func askWhatHappened() {
    guard whatHappenedAvailable else { return }
    stage = .check
  }

  func chooseCheckAnswer(_ answer: PondAnswer) {
    guard !answerRevealed else { return }
    checkAnswer = answer
    if answer == .stuck {
      earnedAnswer = true
      answerRevealed = true
      checkFeedback = prediction == .stuck
        ? "Correct. The light got stuck, just like you guessed."
        : "Correct. The light got stuck inside the pond."
    } else {
      wrongCheckCount += 1
      if wrongCheckCount >= 2 {
        answerRevealed = true
        checkFeedback = "The light got stuck. Let’s find out why."
      } else {
        checkFeedback = "Not quite. Watch the surface as you tilt."
      }
    }
  }

  func startExplanation() {
    guard answerRevealed else { return }
    explanationBeat = 0
    stage = .explanation
  }

  func nextExplanationBeat() {
    guard stage == .explanation else { return }
    if explanationBeat < 2 {
      explanationBeat += 1
    } else {
      stage = .checkpointTwo
    }
  }

  func previousExplanationBeat() {
    guard stage == .explanation, explanationBeat > 0 else { return }
    explanationBeat -= 1
  }

  func chooseCheckpointTwo(_ answer: VineAnswer) {
    checkpointTwoAnswer = answer
  }

  func beginChallenge() {
    checkpointTwoAnswer = checkpointTwoAnswer ?? .pastCritical
    stage = .challenge
    if inputMode == .dial { updateTilt(35) }
    scheduleChallengeHoldIfNeeded()
  }

  func reset() {
    sweepTask?.cancel()
    challengeHoldTask?.cancel()
    sweepTask = nil
    challengeHoldTask = nil
    stage = .entrance
    tilt = 25
    prediction = nil
    checkAnswer = nil
    checkFeedback = nil
    wrongCheckCount = 0
    answerRevealed = false
    explanationBeat = 0
    checkpointTwoAnswer = nil
    hasSeenEscaping = false
    hasSeenTrapped = false
    whatHappenedAvailable = false
    isShowingSweep = false
    earnedGuess = false
    earnedAnswer = false
    earnedChallenge = false
  }

  private func updateTilt(_ newAngle: Double) {
    let oldState = GlassOptics.snapshot(at: tilt).state
    tilt = min(max(newAngle, 0), 60)
    let newState = GlassOptics.snapshot(at: tilt).state
    if (oldState == .trapped) != (newState == .trapped) {
      thresholdCrossings += 1
    }
    if stage == .experiment || stage == .check {
      if newState == .escaping { hasSeenEscaping = true }
      if newState == .trapped { hasSeenTrapped = true }
      if hasSeenEscaping && hasSeenTrapped { whatHappenedAvailable = true }
    }
    scheduleChallengeHoldIfNeeded()
  }

  private func scheduleChallengeHoldIfNeeded() {
    guard stage == .challenge, tilt >= GlassOptics.criticalAngle else {
      challengeHoldTask?.cancel()
      challengeHoldTask = nil
      return
    }
    guard challengeHoldTask == nil else { return }
    challengeHoldTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 300_000_000)
      guard !Task.isCancelled else { return }
      if stage == .challenge && tilt >= GlassOptics.criticalAngle {
        earnedChallenge = true
        stage = .solved
        wins += 1
        UserDefaults.standard.set(true, forKey: "glassPondCompleted")
        previouslyCompleted = true
      }
      challengeHoldTask = nil
    }
  }
}

enum GlassPondStage: Equatable {
  case entrance
  case prediction
  case experiment
  case check
  case explanation
  case checkpointTwo
  case challenge
  case solved
}

enum PondInputMode: Equatable {
  case dial
  case hinge
}

enum PondAnswer: String, CaseIterable, Identifiable {
  case easier
  case stuck
  case noChange

  var id: String { rawValue }

  var title: String {
    switch self {
    case .easier: "It gets out easier"
    case .stuck: "It gets stuck"
    case .noChange: "No change"
    }
  }
}

enum VineAnswer: String, CaseIterable, Identifiable {
  case underCritical
  case pastCritical

  var id: String { rawValue }

  var title: String {
    switch self {
    case .underCritical: "Under 42°"
    case .pastCritical: "Past 42°"
    }
  }
}
