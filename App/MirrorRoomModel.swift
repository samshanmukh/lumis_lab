import SwiftUI
import Observation

/// The Mirror Room’s flow: checkpoints, the fold, the count, the why beats and the challenge.
@MainActor
@Observable
final class MirrorRoomModel: CheckpointRoom {
  static let tryItGoal: Double = 90
  static let challengeGoal: Double = 60
  static let rightCount = 4

  let app: AppModel
  let hinge: HingeModel

  private(set) var step: RoomStep
  private(set) var checkpoint = CheckpointState()

  private(set) var heldAtGoal = false
  private(set) var goalOverride: Double?
  private var overrideAnchor: Double = 0

  private(set) var countPick: Int?
  private(set) var countOutcome: CountOutcome?
  private(set) var countWrongTries = 0
  private(set) var worried = false
  private(set) var pulsingLumi: Int?

  private(set) var whyBeat = 0
  var showingMath = false

  private(set) var challengeCount = 0

  private(set) var hint: HintState?
  private(set) var demoAngle: Double?
  private var hintLevels: [RoomStep: Int] = [:]
  private var demoTask: Task<Void, Never>?
  private var yourTurnTask: Task<Void, Never>?
  private var autoHintTask: Task<Void, Never>?
  private var autoHintShown = false
  private var demoRestoreAngle: Double?

  private(set) var successTick = 0
  private(set) var softTick = 0
  private(set) var selectionTick = 0
  private(set) var floorPulse = 0

  private var inGoalZone = false
  private var inWinZone = false
  private var currentNeat: Double?
  private var holdTask: Task<Void, Never>?
  private var moodTask: Task<Void, Never>?

  init(app: AppModel, hinge: HingeModel) {
    self.app = app
    self.hinge = hinge
    let saved = app.mirror.step
    step = saved == .door || saved == .roomEnd ? .checkpoint1 : saved
    challengeCount = MirrorOptics.challengeCount(for: hinge.mirrorAngle, goal: Self.challengeGoal)
  }

  // MARK: Scene

  var sceneAngle: Double {
    switch step {
    case .check, .why: Self.tryItGoal
    case .solved: Self.challengeGoal
    default: demoAngle ?? goalOverride ?? hinge.mirrorAngle
    }
  }

  var isLive: Bool { step == .tryIt || step == .challenge }

  var sceneMood: LumiMood {
    switch step {
    case .check:
      if worried { return .worried }
      switch countOutcome {
      case .right: return .happy
      case .wrong, .revealed: return .calm
      case nil: return .wonder
      }
    case .why, .solved: return .happy
    default: return .wonder
    }
  }

  var sceneCount: Int { MirrorOptics.count(for: sceneAngle) }

  // MARK: Checkpoints

  var checkpointNumber: Int { step == .checkpoint2 ? 2 : 1 }

  func answer(_ choice: CheckpointChoice) {
    guard checkpoint.outcome == nil else { return }
    let isFirst = step == .checkpoint1
    let right: CheckpointChoice = isFirst ? .number(Self.rightCount) : .closer
    let outcome: CheckpointOutcome = choice == .notSure ? .notSure : (choice == right ? .right : .wrong)

    withAnimation(.easeOut(duration: 0.2)) {
      checkpoint = CheckpointState(picked: choice, outcome: outcome)
    }
    app.updateRoom { state in
      state.checkpoints[isFirst ? 1 : 2] = choice.savedValue
      if isFirst, case .number(let value) = choice { state.guess = value }
      if isFirst, choice == .notSure { state.guess = nil }
      switch (isFirst, outcome) {
      case (true, .right): state.fireflies.formUnion([.guess, .answer])
      case (true, .wrong): state.fireflies.insert(.guess)
      case (false, .right): state.fireflies.insert(.challenge)
      default: break
      }
    }

    switch outcome {
    case .right: successTick += 1
    case .wrong: softTick += 1
    case .notSure: break
    }
    announce(checkpointFeedback ?? "")
  }

  var checkpointFeedback: String? {
    switch (step, checkpoint.outcome) {
    case (.checkpoint1, .right): "Yes! The real Lumi and three reflections."
    case (.checkpoint2, .right): "Yes! Closer mirrors make more Lumis."
    case (_, .wrong): "Not quite. Want to see it?"
    case (_, .notSure): "That’s okay. Want to see it?"
    default: nil
    }
  }

  var checkpointQuestion: CheckpointQuestion {
    if step == .checkpoint1 {
      return CheckpointQuestion(
        title: "At 90°, how many Lumis?",
        detail: "Count the real Lumi too.",
        options: [2, 3, 4, 6].map { CheckpointOption(choice: .number($0), title: "\($0)", outline: .circle(64)) }
      )
    }
    return CheckpointQuestion(
      title: "For more Lumis, move the mirrors…",
      options: [
        CheckpointOption(choice: .closer, title: "Closer together", outline: .capsule),
        CheckpointOption(choice: .further, title: "Further apart", outline: .capsule)
      ]
    )
  }

  var checkpointForwardTitle: String { step == .checkpoint1 ? "Next" : "Next: The Glass Pond" }

  /// Next (after a right answer) or Skip (after a wrong one or I’m not sure).
  func checkpointForward() {
    go(to: step == .checkpoint1 ? .checkpoint2 : .roomEnd)
  }

  /// The step See it lands on, played with the seeIt transition.
  var seeItDestination: RoomStep { step == .checkpoint1 ? .tryIt : .challenge }

  // MARK: Try it

  func showMeGoal() {
    closeHint()
    turnToGoal()
  }

  /// Turns the mirrors to 90° without the hinge; counts as reaching 90°.
  private func turnToGoal() {
    if hinge.usesDial {
      hinge.setDialAngle(Self.tryItGoal, animation: .easeInOut(duration: 0.8))
    } else {
      overrideAnchor = hinge.mirrorAngle
      withAnimation(.easeInOut(duration: 0.8)) { goalOverride = Self.tryItGoal }
    }
    holdTask?.cancel()
    holdTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(800))
      guard let self, !Task.isCancelled, self.step == .tryIt else { return }
      self.inGoalZone = true
      withAnimation(LabMotion.step) { self.heldAtGoal = true }
      self.announce("90 degrees. Count is available.")
    }
  }

  func countThem() {
    go(to: .check)
  }

  // MARK: Count

  func answerCount(_ value: Int) {
    guard countOutcome != .right, countOutcome != .revealed else { return }
    countPick = value
    if value == Self.rightCount {
      withAnimation(.easeOut(duration: 0.2)) { countOutcome = .right }
      successTick += 1
      app.updateRoom { $0.fireflies.insert(.answer) }
      announce("\(countResultLine). 1 real Lumi plus 3 reflections equals 4.")
      return
    }

    countWrongTries += 1
    app.updateRoom { $0.wrongTries += 1 }
    softTick += 1
    if countWrongTries >= 2 {
      withAnimation(.easeOut(duration: 0.2)) {
        countOutcome = .revealed
        countPick = Self.rightCount
      }
      announce("It’s 4. Let’s see why.")
    } else {
      withAnimation(.easeOut(duration: 0.2)) { countOutcome = .wrong }
      announce("Not quite. Count again, the real one too.")
      startWorriedThenPulse()
    }
  }

  var countResultLine: String {
    guard let guess = app.mirror.guess, app.mirror.checkpoints[1] != "notSure" else {
      return "Now you know: 4."
    }
    return guess == Self.rightCount ? "Yes, 4, just like you guessed!" : "Yes, 4! You guessed \(guess)."
  }

  private func startWorriedThenPulse() {
    moodTask?.cancel()
    worried = true
    moodTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(1200))
      guard let self, !Task.isCancelled else { return }
      withAnimation(.easeInOut(duration: 0.2)) { self.worried = false }
      await self.pulseLumis(every: .milliseconds(150))
    }
  }

  /// Lights each Lumi in turn, real one first, to help counting.
  func pulseLumis(every interval: Duration) async {
    for index in 0..<sceneCount {
      guard !Task.isCancelled else { break }
      withAnimation(.spring(duration: 0.3, bounce: 0.4)) { pulsingLumi = index }
      try? await Task.sleep(for: interval)
    }
    withAnimation(.spring(duration: 0.3)) { pulsingLumi = nil }
  }

  func startWhy() {
    go(to: .why)
  }

  // MARK: Why

  static let whyBeats = 3

  func nextBeat() {
    if whyBeat < Self.whyBeats - 1 {
      withAnimation(LabMotion.step) { whyBeat += 1 }
    } else {
      go(to: .checkpoint2)
    }
  }

  func previousBeat() {
    guard whyBeat > 0 else { return }
    withAnimation(LabMotion.step) { whyBeat -= 1 }
  }

  func setBeat(_ beat: Int) {
    let clamped = min(Self.whyBeats - 1, max(0, beat))
    guard clamped != whyBeat else { return }
    withAnimation(LabMotion.step) { whyBeat = clamped }
  }

  // MARK: Solved and room end

  var challengeStatus: String {
    challengeCount < 6 ? "\(challengeCount) now. Fold a little more." : "\(challengeCount) now. Open a little."
  }

  var challengeOvershot: Bool { challengeCount > 6 }

  func finishRoom() {
    go(to: .roomEnd)
  }

  // MARK: Angle input

  /// Call on every hinge or dial update and after each step change.
  func angleChanged() {
    guard !isDemoPlaying else { return }
    let live = hinge.mirrorAngle
    if goalOverride != nil, abs(live - overrideAnchor) > 3 {
      withAnimation(LabMotion.hinge) { goalOverride = nil }
    }
    guard isLive else { return }
    let angle = sceneAngle

    let neat = MirrorOptics.neatAngle(near: angle)
    if neat != currentNeat {
      currentNeat = neat
      if neat != nil {
        selectionTick += 1
        floorPulse += 1
      }
    }

    switch step {
    case .tryIt: updateGoalHold(angle)
    case .challenge: updateChallenge(angle)
    default: break
    }
  }

  private func updateGoalHold(_ angle: Double) {
    let inZone = abs(angle - Self.tryItGoal) <= MirrorOptics.tolerance
    guard inZone != inGoalZone else { return }
    inGoalZone = inZone
    holdTask?.cancel()
    holdTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(300))
      guard let self, !Task.isCancelled, self.step == .tryIt else { return }
      guard self.heldAtGoal != inZone else { return }
      withAnimation(LabMotion.step) { self.heldAtGoal = inZone }
      if inZone { self.announce("90 degrees. Count is available.") }
    }
  }

  private func updateChallenge(_ angle: Double) {
    let count = MirrorOptics.challengeCount(for: angle, goal: Self.challengeGoal)
    if count != challengeCount {
      challengeCount = count
      announce(challengeStatus)
      scheduleAutoHint()
    }
    let inZone = abs(angle - Self.challengeGoal) <= MirrorOptics.tolerance
    guard inZone != inWinZone else { return }
    inWinZone = inZone
    holdTask?.cancel()
    guard inZone else { return }
    holdTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(300))
      guard let self, !Task.isCancelled, self.step == .challenge, self.inWinZone else { return }
      self.win()
    }
  }

  private func win() {
    app.updateRoom { $0.fireflies.insert(.challenge) }
    successTick += 1
    go(to: .solved)
    let earned = app.mirror.fireflies.count
    announce("6 Lumis. Room complete, \(earned) of 3 fireflies.")
  }

  // MARK: Steps

  func go(to next: RoomStep) {
    holdTask?.cancel()
    moodTask?.cancel()
    demoTask?.cancel()
    yourTurnTask?.cancel()
    withAnimation(LabMotion.step) {
      step = next
      hint = nil
      demoAngle = nil
      heldAtGoal = false
      goalOverride = nil
      worried = false
      pulsingLumi = nil
      showingMath = false
      if next == .checkpoint1 || next == .checkpoint2 { checkpoint = CheckpointState() }
      if next == .check {
        countPick = nil
        countOutcome = nil
        countWrongTries = 0
      }
      if next == .why { whyBeat = 0 }
    }
    inGoalZone = false
    inWinZone = false
    currentNeat = MirrorOptics.neatAngle(near: sceneAngle)
    challengeCount = MirrorOptics.challengeCount(for: sceneAngle, goal: Self.challengeGoal)
    if next == .roomEnd {
      app.updateRoom { state in
        state.step = .roomEnd
        state.solved = true
      }
    } else {
      app.setStep(next)
    }
    angleChanged()
    scheduleAutoHint()
  }

  // MARK: Hints

  var hintContent: HintContent? { Self.hintContent(for: step) }
  var isDemoPlaying: Bool { hint?.phase == .showing }

  /// The Hint toolbar item: opens at the last level seen on this step, or closes.
  func toggleHint() {
    if hint != nil {
      closeHint()
    } else {
      openHint()
    }
  }

  func openHint() {
    guard let content = hintContent else { return }
    let level = min(hintLevels[step] ?? 1, content.levels.count)
    hintLevels[step] = level
    showingMath = false
    withAnimation(LabMotion.panel) { hint = HintState(level: level) }
    announce("Hint. \(content.levels[level - 1])")
  }

  func anotherHint() {
    guard var current = hint, let content = hintContent, current.level < content.levels.count else { return }
    current.level += 1
    hintLevels[step] = current.level
    withAnimation(.spring(duration: 0.35, bounce: 0.1)) { hint = current }
    announce(content.levels[current.level - 1])
    if step == .check, current.level == 2 {
      demoTask?.cancel()
      demoTask = Task { @MainActor [weak self] in
        await self?.pulseLumis(every: .milliseconds(400))
      }
    }
  }

  func closeHint() {
    guard hint != nil else { return }
    if isDemoPlaying { handBack() }
    demoTask?.cancel()
    yourTurnTask?.cancel()
    withAnimation(.easeIn(duration: 0.2)) { hint = nil }
  }

  /// Level 3: Lumi shows the move once, then hands control back.
  func showMe() {
    guard hint != nil, !isDemoPlaying else { return }
    demoTask?.cancel()
    holdTask?.cancel()
    withAnimation(.spring(duration: 0.3, bounce: 0.1)) { hint?.phase = .showing }
    demoTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await self.playDemo()
      guard !Task.isCancelled else { return }
      self.demoFinished()
    }
  }

  /// Stop ends the demo early and hands back the student’s own angle.
  func stopDemo() {
    guard isDemoPlaying else { return }
    demoTask?.cancel()
    handBack()
    showYourTurn()
  }

  private func playDemo() async {
    let start = ContinuousClock.now
    switch step {
    case .tryIt:
      announce("Showing you. Turning the mirrors to 90 degrees.")
      demoRestoreAngle = hinge.mirrorAngle
      turnToGoal()
    case .check:
      announce("Showing you. Watch each Lumi light up.")
      try? await Task.sleep(for: .milliseconds(300))
      await pulseLumis(every: .milliseconds(800))
    case .challenge:
      announce("Showing you. Folding to 60 degrees.")
      demoAngle = hinge.mirrorAngle
      withAnimation(.easeInOut(duration: 1.4)) { demoAngle = Self.challengeGoal }
      try? await Task.sleep(for: .milliseconds(2800))
      guard !Task.isCancelled else { return }
      withAnimation(.easeInOut(duration: 1.2)) { demoAngle = hinge.mirrorAngle }
      try? await Task.sleep(for: .milliseconds(1200))
      guard !Task.isCancelled else { return }
      demoAngle = nil
    default:
      break
    }
    try? await Task.sleep(until: start + .seconds(4), clock: .continuous)
  }

  private func demoFinished() {
    if step == .tryIt {
      // Show me counts as reaching 90°: the mirrors stay there until the student moves them.
      overrideAnchor = hinge.mirrorAngle
      inGoalZone = true
      if !heldAtGoal { withAnimation(LabMotion.step) { heldAtGoal = true } }
    }
    showYourTurn()
  }

  private func handBack() {
    withAnimation(LabMotion.hinge) { pulsingLumi = nil }
    switch step {
    case .tryIt:
      holdTask?.cancel()
      withAnimation(.easeInOut(duration: 0.3)) {
        goalOverride = nil
        heldAtGoal = false
      }
      if let restore = demoRestoreAngle, hinge.usesDial {
        hinge.setDialAngle(restore, animation: .easeInOut(duration: 0.3))
      }
      inGoalZone = false
    case .challenge:
      withAnimation(.easeInOut(duration: 0.3)) { demoAngle = hinge.mirrorAngle }
      Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(300))
        self?.demoAngle = nil
      }
    default:
      break
    }
    demoRestoreAngle = nil
  }

  private func showYourTurn() {
    withAnimation(.spring(duration: 0.3, bounce: 0.1)) { hint?.phase = .yourTurn }
    announce("Your turn.")
    angleChanged()
    yourTurnTask?.cancel()
    yourTurnTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(2))
      guard let self, !Task.isCancelled, self.hint?.phase == .yourTurn else { return }
      withAnimation(.easeIn(duration: 0.2)) { self.hint = nil }
    }
  }

  /// Once per room, the hint opens by itself after 45 s without progress on the challenge.
  private func scheduleAutoHint() {
    autoHintTask?.cancel()
    guard step == .challenge, !autoHintShown else { return }
    autoHintTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(45))
      guard let self, !Task.isCancelled, self.step == .challenge, self.hint == nil else { return }
      self.autoHintShown = true
      self.openHint()
    }
  }

  static func hintContent(for step: RoomStep) -> HintContent? {
    switch step {
    case .tryIt:
      HintContent(levels: [
        "Close your phone like a book.",
        "Stop when the glowing mirrors sit on the gold dashes.",
        "Lumi can turn the mirrors to 90° for you. Then the phone is yours again."
      ], showMeTitle: "Show me 90°")
    case .check:
      HintContent(levels: [
        "Count every Lumi, the real one too.",
        "Watch each Lumi light up in turn and count along.",
        "Lumi can light up each Lumi, starting with the real one. Count along!"
      ], showMeTitle: "Show me")
    case .challenge:
      HintContent(levels: [
        "Fold more for more Lumis, open for fewer.",
        "360 ÷ 6 gives the angle.",
        "Watch Lumi do it once. Then the phone is yours again, at the angle you had."
      ], showMeTitle: "Show me")
    case .why:
      HintContent(levels: ["Read the words, then find them in the picture."], showMeTitle: nil)
    case .solved:
      HintContent(levels: ["You made 6 Lumis! Tap Next when you’re ready."], showMeTitle: nil)
    default:
      nil
    }
  }

  func announce(_ text: String) {
    guard !text.isEmpty else { return }
    AccessibilityNotification.Announcement(text).post()
  }
}

enum CheckpointChoice: Hashable {
  case number(Int)
  case closer
  case further
  /// A worded answer from another room, saved as its own value.
  case option(String)
  case notSure

  var savedValue: String {
    switch self {
    case .number(let value): String(value)
    case .closer: "closer"
    case .further: "further"
    case .option(let value): value
    case .notSure: "notSure"
    }
  }
}

enum CheckpointOutcome {
  case right
  case wrong
  case notSure
}

struct CheckpointState {
  var picked: CheckpointChoice?
  var outcome: CheckpointOutcome?
}

enum CountOutcome {
  case right
  case wrong
  case revealed
}

struct HintState: Equatable {
  var level: Int
  var phase: HintPhase = .panel
}

enum HintPhase {
  case panel
  case showing
  case yourTurn
}

struct HintContent {
  var levels: [String]
  /// The level 3 action, when the step has a Show me.
  var showMeTitle: String?
}
