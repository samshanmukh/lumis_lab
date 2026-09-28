import SwiftUI
import Observation

/// musa’s Marble Ramp chapter, played like the other rooms: set the ramp with the hinge (or the
/// dial without one) and roll until the marble wakes the firefly, predict which of two ramps rolls
/// a marble farther, then see why. The moon garden stays put; only the words and controls change.
@MainActor
@Observable
final class MarbleChapterRoom {
  enum Stage: Int {
    case experiment = 1
    case quiz
    case why
    case roomEnd
  }

  static let room: RoomID = .marbleRamp
  /// The stages with a progress dot.
  static let stageCount = 3

  let app: AppModel
  let hinge: HingeModel

  private(set) var stage: Stage = .experiment
  var ramp = MarbleChapterModel()
  private(set) var quiz = MarbleQuizModel()
  private var rolls: [ChapterRoll] = []
  private var trail: [CGPoint] = []
  private var quizLandedAt = Date.distantPast

  private(set) var hint: HintState?
  private var hintLevels: [Stage: Int] = [:]
  private var rollTask: Task<Void, Never>?
  private var quizTask: Task<Void, Never>?

  private(set) var successTick = 0
  private(set) var selectionTick = 0

  init(app: AppModel, hinge: HingeModel) {
    self.app = app
    self.hinge = hinge
    // Without a live hinge, the dial starts on a ramp that stops short.
    if hinge.usesDial {
      hinge.setDialAngle(MarbleChapterModel.openingAngle(forRamp: 20))
    }
    ramp.updateHinge(rawOpeningAngle: hinge.angle)
    app.setStep(.tryIt, room: Self.room)
  }

  // MARK: Experiment

  var usesDial: Bool { hinge.usesDial }

  func hingeChanged() {
    ramp.updateHinge(rawOpeningAngle: hinge.angle)
  }

  func roll() {
    guard stage == .experiment, ramp.canRoll else { return }
    closeHint()
    let angle = ramp.rampDegrees
    ramp.startTrial()
    trail = []
    rollTask?.cancel()
    rollTask = Task { @MainActor [weak self] in
      var last = Date.now
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(16))
        guard let self, !Task.isCancelled else { return }
        let now = Date.now
        self.ramp.advance(by: now.timeIntervalSince(last))
        last = now
        self.leaveTrail()
        if !self.ramp.isRolling {
          self.landed(angle: angle)
          return
        }
      }
    }
  }

  private func landed(angle: Double) {
    selectionTick += 1
    rolls.append(ChapterRoll(
      angle: angle,
      x: ChapterGarden.x(forFraction: ramp.ballFraction),
      wokeFirefly: ramp.fireflyAwake,
      landedAt: .now
    ))
    if ramp.fireflyAwake {
      successTick += 1
      app.updateRoom(Self.room) { $0.fireflies.insert(.challenge) }
      announce("The firefly woke up!")
    } else {
      announce(rollStatus ?? "")
    }
  }

  /// How the last roll went, said once per roll under the ramp angle.
  var rollStatus: String? {
    guard !ramp.isRolling, !ramp.fireflyAwake, let outcome = ramp.lastOutcome else { return nil }
    let near = abs(ramp.ballFraction - MarbleChapterModel.targetFraction) <= ChapterGarden.nearMiss
    switch outcome {
    case .short: return near ? "Almost! Make it a bit steeper." : "It stopped short. Try a steeper ramp."
    case .long: return near ? "Almost! Make it a bit gentler." : "It rolled past. Try a gentler ramp."
    case .target: return nil
    }
  }

  /// Faint dots behind the rolling marble, about one every 19 pt of garden.
  private func leaveTrail() {
    let center = marbleCenter
    if let last = trail.last, hypot(center.x - last.x, center.y - last.y) < 19 { return }
    trail.append(center)
  }

  /// Mass doesn’t change the roll, but a heavier marble looks bigger.
  private var marbleRadius: CGFloat { ChapterGarden.marbleRadius(forMass: ramp.mass) }

  /// Where the marble is now: down the ramp, then along the path to where it stopped.
  private var marbleCenter: CGPoint {
    switch ramp.phase {
    case .ready, .ramp:
      return MarbleTrack(angle: ramp.rampDegrees, start: .top).descentCenter(ramp.rampProgress, radius: marbleRadius)
    case .flat, .stopped:
      // In the flower, the marble settles into its cup.
      let settle: CGFloat = ramp.fireflyAwake ? 4 : 0
      return CGPoint(x: ChapterGarden.x(forFraction: ramp.ballFraction), y: MarbleGarden.groundY - marbleRadius + settle)
    }
  }

  func startQuiz() {
    go(to: .quiz)
  }

  // MARK: Prediction

  func pick(_ choice: QuizRamp) {
    guard stage == .quiz, quiz.selected == nil else { return }
    closeHint()
    withAnimation(.snappy) { quiz.select(choice) }
    app.updateRoom(Self.room) { state in
      state.checkpoints[1] = choice.rawValue
      state.fireflies.insert(.guess)
    }
    announce("\(choice.title). Your pick rolls first.")
    quizTask?.cancel()
    quizTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(max(0, self?.quiz.completionDelay ?? 0)))
      guard let self, !Task.isCancelled else { return }
      self.finishQuiz()
    }
  }

  private func finishQuiz() {
    quizLandedAt = .now
    withAnimation(.easeOut(duration: 0.2)) { quiz.finished = true }
    selectionTick += 1
    if quiz.pickedRight {
      successTick += 1
      app.updateRoom(Self.room) { $0.fireflies.insert(.answer) }
    }
    announce(quizFeedback ?? "")
  }

  var quizFeedback: String? {
    guard quiz.finished else { return nil }
    return quiz.pickedRight ? "Yes! You guessed it." : "It’s the steep one. Let’s see why."
  }

  func startWhy() {
    go(to: .why)
  }

  func finish() {
    go(to: .roomEnd)
  }

  // MARK: Hints

  var hintContent: HintContent? {
    switch stage {
    case .experiment where !ramp.fireflyAwake:
      HintContent(levels: [
        "Set the ramp, then tap Roll.",
        "Stopped short? Make the ramp steeper. Rolled past? Make it gentler."
      ])
    case .quiz where quiz.selected == nil:
      HintContent(levels: ["Look at where each marble starts."])
    default:
      nil
    }
  }

  func toggleHint() {
    if hint != nil { closeHint() } else { openHint() }
  }

  func openHint() {
    guard let content = hintContent else { return }
    let level = min(hintLevels[stage] ?? 1, content.levels.count)
    hintLevels[stage] = level
    withAnimation(LabMotion.panel) { hint = HintState(level: level) }
    announce("Hint. \(content.levels[level - 1])")
  }

  func anotherHint() {
    guard var current = hint, let content = hintContent, current.level < content.levels.count else { return }
    current.level += 1
    hintLevels[stage] = current.level
    withAnimation(.spring(duration: 0.35, bounce: 0.1)) { hint = current }
    announce(content.levels[current.level - 1])
  }

  func closeHint() {
    guard hint != nil else { return }
    withAnimation(.easeIn(duration: 0.2)) { hint = nil }
  }

  // MARK: Stages

  private func go(to next: Stage) {
    withAnimation(LabMotion.step) {
      stage = next
      hint = nil
    }
    switch next {
    case .experiment: app.setStep(.tryIt, room: Self.room)
    case .quiz: app.setStep(.check, room: Self.room)
    case .why: app.setStep(.why, room: Self.room)
    case .roomEnd:
      app.updateRoom(Self.room) { state in
        state.step = .roomEnd
        state.solved = true
      }
    }
  }

  func announce(_ text: String) {
    guard !text.isEmpty else { return }
    AccessibilityNotification.Announcement(text).post()
  }

  // MARK: Scene

  /// What the moon garden shows on this stage.
  var scene: MarbleSceneState {
    var scene = MarbleSceneState()
    scene.showsStarLine = false
    switch stage {
    case .experiment:
      let track = MarbleTrack(angle: ramp.rampDegrees, start: .top)
      scene.ramps = ghostRamp(for: track) + [RampMark(track: track)]
      scene.flags = flags
      scene.trail = trail
      scene.marbleRadius = marbleRadius
      scene.restingMarbles = [marbleCenter]
      scene.flowerOpen = ramp.fireflyAwake
      scene.lumiMood = experimentMood
      scene.accessibilityValue = experimentValue
    case .quiz, .why:
      scene.ramps = QuizRamp.allCases.map { RampMark(track: $0.track) }
      scene.callouts = .startHeights
      // The firefly stays awake in its flower; the others drift off to leave room for the rolls.
      scene.flowerOpen = true
      scene.firefliesGather = false
      if quiz.finished {
        scene.restingMarbles = QuizRamp.allCases.map(\.track.restCenter)
        scene.flags = FlagMark.marks(for: [(x: QuizRamp.gentle.track.restX, label: "gentle", landedAt: quizLandedAt)])
        scene.lumiMood = .happy
        scene.accessibilityValue = "The gentle ramp’s marble stopped partway. The steep ramp’s marble rolled all the way to the flower."
      } else if quiz.selected != nil {
        scene.rolling = quiz.marbles
        scene.lumiMood = .wonder
        scene.accessibilityValue = "Both marbles are rolling."
      } else {
        scene.restingMarbles = QuizRamp.allCases.map(\.track.startCenter)
        scene.lumiMood = .calm
        scene.accessibilityValue = "Two ramps the same length, each with a marble at the top. The gentle ramp starts lower and the steep ramp starts higher."
      }
    case .roomEnd:
      break
    }
    return scene
  }

  /// The last roll’s ramp, as a ghost, when the ramp has moved since.
  private func ghostRamp(for track: MarbleTrack) -> [RampMark] {
    guard let last = rolls.last, abs(last.angle - track.angle) > 2 else { return [] }
    return [RampMark(track: MarbleTrack(angle: last.angle, start: .top), isGhost: true)]
  }

  /// A flag with its ramp angle where each of the last few rolls stopped, if it’s in the garden.
  private var flags: [FlagMark] {
    let shown = rolls.suffix(3).filter { !$0.wokeFirefly && $0.x <= ChapterGarden.flagLimit }
    return FlagMark.marks(for: shown.map { (x: $0.x, label: "\(Int($0.angle.rounded()))°", landedAt: $0.landedAt) })
  }

  /// Lumi watches the marble: calm before a roll, wide-eyed while it rolls, worried when it
  /// misses, and happy when the firefly wakes.
  private var experimentMood: LumiMood {
    if ramp.fireflyAwake { return .happy }
    if ramp.isRolling { return .wonder }
    if ramp.lastOutcome != nil { return .worried }
    return .calm
  }

  private var experimentValue: String {
    let angle = Int(ramp.rampDegrees.rounded())
    if ramp.fireflyAwake { return "The marble rolled into the flower and the firefly woke up." }
    if ramp.isRolling { return "The marble is rolling down a \(angle)° ramp." }
    switch ramp.lastOutcome {
    case .short: return "The marble stopped short of the firefly."
    case .long: return "The marble rolled past the firefly."
    default: return "A \(angle)° ramp. The marble waits at the top, and the firefly sleeps in the flower."
    }
  }
}

/// A finished roll in the chapter: its ramp and where the marble stopped.
private struct ChapterRoll {
  var angle: Double
  var x: CGFloat
  var wokeFirefly: Bool
  var landedAt: Date
}

/// Where the chapter’s marble goes in the moon garden: its ramp ends where the garden’s ramp meets
/// the path, and its target is the flower, so every stop lands in proportion between the two.
private enum ChapterGarden {
  static let rampEndX = MarbleGarden.foot.x + MarbleGarden.curve
  static let scale = (MarbleGarden.cupX - rampEndX)
    / CGFloat(MarbleChapterModel.targetFraction - MarbleChapterModel.rampEndFraction)
  /// Stops this close to the target, in the chapter’s track fraction, are “almost”.
  static let nearMiss = 0.08
  /// Flags past this are off the garden’s edge.
  static let flagLimit: CGFloat = 655

  static func x(forFraction fraction: Double) -> CGFloat {
    rampEndX + CGFloat(fraction - MarbleChapterModel.rampEndFraction) * scale
  }

  static func marbleRadius(forMass mass: Double) -> CGFloat {
    MarbleGarden.marbleRadius * CGFloat(0.75 + 0.75 * (mass - 5) / 95)
  }
}
