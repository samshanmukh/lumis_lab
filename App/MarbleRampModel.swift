import SwiftUI
import Observation

/// The Marble Ramp’s flow: roll from the star to find that height (not steepness) decides how far
/// a marble rolls, then use it to wake the firefly from the top of the ramp.
@MainActor
@Observable
final class MarbleRampModel {
  static let room: RoomID = .marbleRamp
  /// Two rolls at least this far apart count as “a gentle one and a steep one”.
  static let tryItSpread: Double = 20

  let app: AppModel
  let hinge: HingeModel

  private(set) var step: RoomStep
  private(set) var checkpoint = CheckpointState()

  private(set) var tryRolls: [MarbleRoll] = []
  private(set) var challengeRolls: [MarbleRoll] = []
  private(set) var rolling: [RollingMarble] = []
  private(set) var trail: [CGPoint] = []
  private(set) var readyToAsk = false
  private(set) var demoAngle: Double?
  private(set) var challengeStatus: String?

  private(set) var checkPick: CheckpointChoice?
  private(set) var checkOutcome: CountOutcome?
  private var checkWrongTries = 0
  private(set) var labelPulse = 0

  private(set) var whyBeat = 0
  var showingMath = false

  private(set) var hint: HintState?
  private var hintLevels: [RoomStep: Int] = [:]
  private var demoTask: Task<Void, Never>?
  private var rollTask: Task<Void, Never>?
  private var yourTurnTask: Task<Void, Never>?
  private var autoHintTask: Task<Void, Never>?
  private var autoHintShown = false

  private(set) var successTick = 0
  private(set) var softTick = 0
  private(set) var selectionTick = 0

  init(app: AppModel, hinge: HingeModel) {
    self.app = app
    self.hinge = hinge
    let saved = app.state(Self.room).step
    step = saved == .door || saved == .roomEnd ? .checkpoint1 : saved
    if step == .check || step == .why { tryRolls = Self.exampleRolls }
    scheduleAutoHint()
  }

  private var state: RoomState { app.state(Self.room) }

  // MARK: Ramp

  var isLive: Bool { step == .tryIt || step == .challenge }
  var isRolling: Bool { !rolling.isEmpty }
  /// Lumi is showing a move; the hinge and dial wait until it ends.
  var isDemoPlaying: Bool { demoTask != nil }

  /// The tilt shown and used: a roll keeps its tilt until it stops, and a demo sets its own.
  var rampAngle: Double {
    if let rolling = rolling.last { return rolling.track.angle }
    if let demoAngle { return demoAngle }
    switch step {
    case .checkpoint2: return 30
    case .solved: return challengeRolls.last(where: \.track.reachesCup)?.track.angle ?? 45
    default: return hinge.rampAngle.rounded()
    }
  }

  var usesDial: Bool { isLive && hinge.usesDial }

  // MARK: Rolling

  func roll() {
    guard rolling.isEmpty, demoTask == nil else { return }
    let track = MarbleTrack(angle: rampAngle, start: step == .challenge ? .top : .star)
    rollTask?.cancel()
    rollTask = Task { @MainActor [weak self] in
      await self?.play([track], records: true)
    }
  }

  /// Rolls marbles together, waits for them to stop, then plants their flags.
  private func play(_ tracks: [MarbleTrack], records: Bool) async {
    let now = Date()
    let marbles = tracks.map { RollingMarble(track: $0, plan: $0.plan(), startedAt: now) }
    rolling = marbles
    let duration = marbles.map(\.plan.duration).max() ?? 0
    try? await Task.sleep(for: .seconds(duration))
    guard !Task.isCancelled else {
      rolling = []
      return
    }
    rolling = []
    trail = marbles.last?.plan.trail ?? []
    selectionTick += 1
    for marble in marbles where records {
      landed(marble.track)
    }
  }

  private func landed(_ track: MarbleTrack) {
    let roll = MarbleRoll(track: track, landedAt: .now)
    switch step {
    case .tryIt:
      withAnimation(.spring(duration: 0.45, bounce: 0.35)) { tryRolls.append(roll) }
      let angles = tryRolls.map(\.track.angle)
      if !readyToAsk, let low = angles.min(), let high = angles.max(), high - low >= Self.tryItSpread {
        withAnimation(LabMotion.step) { readyToAsk = true }
        announce("Both rolls are done. What happened is available.")
      } else {
        announce("The marble stopped at the flag, from a \(Int(track.angle))° ramp.")
      }
      scheduleAutoHint()
    case .challenge:
      withAnimation(.spring(duration: 0.45, bounce: 0.35)) { challengeRolls.append(roll) }
      if track.reachesCup {
        win()
      } else {
        challengeStatus = MarbleGarden.cupX - track.stopX <= MarbleGarden.nearMiss
          ? "Almost! Make it a bit steeper."
          : "Not far enough yet."
        announce(challengeStatus ?? "")
        scheduleAutoHint()
      }
    default:
      break
    }
  }

  var tryItStatus: String {
    if readyToAsk { return "You rolled a gentle ramp and a steep one." }
    guard let last = tryRolls.last else { return "The marble starts at the star." }
    return last.track.angle < 32.5 ? "Now try a steep ramp." : "Now try a gentle ramp."
  }

  /// Show me: rolls a gentle ramp, then a steep one, by itself. Counts as both.
  func showMeBothRolls() {
    guard rolling.isEmpty, demoTask == nil else { return }
    closeHint()
    demoTask = Task { @MainActor [weak self] in
      await self?.demoBothRolls()
      self?.demoTask = nil
    }
  }

  private func demoBothRolls() async {
    for angle in [20.0, 50.0] {
      withAnimation(.easeInOut(duration: 0.5)) { demoAngle = angle }
      try? await Task.sleep(for: .milliseconds(550))
      guard !Task.isCancelled else { break }
      await play([MarbleTrack(angle: angle, start: .star)], records: true)
      guard !Task.isCancelled else { break }
      try? await Task.sleep(for: .milliseconds(250))
    }
    withAnimation(.easeInOut(duration: 0.4)) { demoAngle = nil }
  }

  func whatHappened() {
    go(to: .check)
  }

  // MARK: Checkpoints

  var checkpointQuestion: CheckpointQuestion {
    if step == .checkpoint2 {
      CheckpointQuestion(
        title: "Starting from the very top, which rolls farther?",
        options: [
          CheckpointOption(choice: .word("steeper"), title: "Steeper ramp"),
          CheckpointOption(choice: .word("gentler"), title: "Gentler ramp"),
          CheckpointOption(choice: .word("same"), title: "Same spot")
        ],
        style: .words,
        forwardTitle: "Next: \(RoomID.launchAngle.title)"
      )
    } else {
      CheckpointQuestion(
        title: "Which marble rolls farther?",
        detail: "Both start at the star.",
        options: Self.rampChoices,
        style: .words,
        forwardTitle: "Next"
      )
    }
  }

  static let rampChoices = [
    CheckpointOption(choice: .word("steep"), title: "Steep ramp"),
    CheckpointOption(choice: .word("gentle"), title: "Gentle ramp"),
    CheckpointOption(choice: .word("same"), title: "Same spot")
  ]

  func answer(_ choice: CheckpointChoice) {
    guard checkpoint.outcome == nil else { return }
    let isFirst = step == .checkpoint1
    let right: CheckpointChoice = isFirst ? .word("same") : .word("steeper")
    let outcome: CheckpointOutcome = choice == .notSure ? .notSure : (choice == right ? .right : .wrong)

    withAnimation(.easeOut(duration: 0.2)) {
      checkpoint = CheckpointState(picked: choice, outcome: outcome)
    }
    app.updateRoom(Self.room) { state in
      state.checkpoints[isFirst ? 1 : 2] = choice.savedValue
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
    case (.checkpoint1, .right): "Yes! Same starting height, same flag."
    case (.checkpoint2, .right): "Yes! A steeper ramp starts higher, so it rolls farther."
    case (_, .wrong): "Not quite. Want to see it?"
    case (_, .notSure): "That’s okay. Want to see it?"
    default: nil
    }
  }

  /// Next (after a right answer) or Skip.
  func checkpointForward() {
    go(to: step == .checkpoint1 ? .checkpoint2 : .roomEnd)
  }

  var seeItDestination: RoomStep { step == .checkpoint1 ? .tryIt : .challenge }

  func seeIt() {
    go(to: seeItDestination)
  }

  // MARK: Check

  func answerCheck(_ choice: CheckpointChoice) {
    guard checkOutcome != .right, checkOutcome != .revealed else { return }
    checkPick = choice
    if choice == .word("same") {
      withAnimation(.easeOut(duration: 0.2)) { checkOutcome = .right }
      successTick += 1
      app.updateRoom(Self.room) { $0.fireflies.insert(.answer) }
      announce("Correct. Both marbles stopped at the same flag.")
      return
    }
    checkWrongTries += 1
    app.updateRoom(Self.room) { $0.wrongTries += 1 }
    softTick += 1
    if checkWrongTries >= 2 {
      withAnimation(.easeOut(duration: 0.2)) {
        checkOutcome = .revealed
        checkPick = .word("same")
      }
      announce("It’s the same spot. Let’s find out why.")
    } else {
      withAnimation(.easeOut(duration: 0.2)) { checkOutcome = .wrong }
      labelPulse += 1
      announce("Not quite. Look where the flag is.")
    }
  }

  var checkFeedback: String? {
    switch checkOutcome {
    case .right:
      "Yes! Same starting height, same speed, same flag." + (state.checkpoints[1] == "same" ? " And you guessed it!" : "")
    case .wrong: "Not quite. Look where the flag is."
    case .revealed: "It’s the same spot. Let’s find out why."
    case nil: nil
    }
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

  /// The gentlest and steepest rolls from Try it, for comparing.
  var comparedTracks: (gentle: MarbleTrack, steep: MarbleTrack) {
    let angles = tryRolls.map(\.track.angle)
    let low = angles.min() ?? 20, high = angles.max() ?? 50
    let spread = high - low >= Self.tryItSpread
    return (MarbleTrack(angle: spread ? low : 20, start: .star), MarbleTrack(angle: spread ? high : 50, start: .star))
  }

  // MARK: Challenge and solved

  private func win() {
    app.updateRoom(Self.room) { $0.fireflies.insert(.challenge) }
    successTick += 1
    go(to: .solved)
    announce("The firefly woke up. Room complete, \(state.fireflies.count) of 3 fireflies.")
  }

  func finishRoom() {
    go(to: .roomEnd)
  }

  // MARK: Hints

  var hintContent: HintContent? { Self.hintContent(for: step) }

  func toggleHint() {
    if hint != nil { closeHint() } else { openHint() }
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
  }

  func closeHint() {
    guard hint != nil else { return }
    if hint?.phase == .showing {
      demoTask?.cancel()
      demoTask = nil
      rolling = []
      withAnimation(.easeInOut(duration: 0.3)) { demoAngle = nil }
    }
    yourTurnTask?.cancel()
    withAnimation(.easeIn(duration: 0.2)) { hint = nil }
  }

  /// Level 3: Lumi shows it once, then hands control back.
  func showMe() {
    guard hint != nil, hint?.phase != .showing, rolling.isEmpty else { return }
    withAnimation(.spring(duration: 0.3, bounce: 0.1)) { hint?.phase = .showing }
    demoTask?.cancel()
    demoTask = Task { @MainActor [weak self] in
      guard let self else { return }
      let start = ContinuousClock.now
      switch self.step {
      case .tryIt:
        self.announce("Showing you. Rolling a gentle ramp, then a steep one.")
        await self.demoBothRolls()
      case .check:
        self.announce("Showing you. Both rolls again, side by side.")
        let compared = self.comparedTracks
        await self.play([compared.gentle, compared.steep], records: false)
      case .challenge:
        self.announce("Showing you. Rolling from a 45 degree ramp.")
        withAnimation(.easeInOut(duration: 0.6)) { self.demoAngle = 45 }
        try? await Task.sleep(for: .milliseconds(650))
        await self.play([MarbleTrack(angle: 45, start: .top)], records: false)
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.easeInOut(duration: 0.5)) { self.demoAngle = nil }
      default:
        break
      }
      try? await Task.sleep(until: start + .seconds(4), clock: .continuous)
      guard !Task.isCancelled else { return }
      self.demoTask = nil
      self.showYourTurn()
    }
  }

  func stopDemo() {
    guard hint?.phase == .showing else { return }
    demoTask?.cancel()
    demoTask = nil
    rolling = []
    withAnimation(.easeInOut(duration: 0.3)) { demoAngle = nil }
    showYourTurn()
  }

  private func showYourTurn() {
    withAnimation(.spring(duration: 0.3, bounce: 0.1)) { hint?.phase = .yourTurn }
    announce("Your turn.")
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
        "Tilt the screen, then tap Roll.",
        "Roll a gentle ramp and a steep one, so you can compare.",
        "Lumi can roll a gentle ramp and a steep one for you."
      ], showMeTitle: "Show me")
    case .check:
      HintContent(levels: [
        "Look where each marble stopped.",
        "Look at the flag. Did one marble pass the other?",
        "Lumi can roll both marbles again, side by side."
      ], showMeTitle: "Show me again")
    case .challenge:
      HintContent(levels: [
        "The marble starts at the very top now.",
        "A steeper ramp lifts the top higher, and a higher start rolls farther.",
        "Watch Lumi roll it once. Then the phone is yours again, at the angle you had."
      ], showMeTitle: "Show me")
    case .why:
      HintContent(levels: ["Read the words, then find them in the picture."], showMeTitle: nil)
    case .solved:
      HintContent(levels: ["You woke the firefly! Tap Next when you’re ready."], showMeTitle: nil)
    default:
      nil
    }
  }

  // MARK: Steps

  func go(to next: RoomStep) {
    rollTask?.cancel()
    demoTask?.cancel()
    demoTask = nil
    yourTurnTask?.cancel()
    withAnimation(LabMotion.step) {
      step = next
      hint = nil
      demoAngle = nil
      rolling = []
      showingMath = false
      if next == .checkpoint1 || next == .checkpoint2 { checkpoint = CheckpointState() }
      if next == .tryIt {
        tryRolls = []
        trail = []
        readyToAsk = false
      }
      if next == .check {
        checkPick = nil
        checkOutcome = nil
        checkWrongTries = 0
        if tryRolls.isEmpty { tryRolls = Self.exampleRolls }
      }
      if next == .why { whyBeat = 0 }
      if next == .challenge {
        challengeRolls = []
        challengeStatus = nil
        trail = []
      }
    }
    if next == .tryIt, hinge.usesDial { hinge.setRampAngle(20) }
    if next == .challenge, hinge.usesDial { hinge.setRampAngle(30) }
    if next == .roomEnd {
      app.updateRoom(Self.room) { state in
        state.step = .roomEnd
        state.solved = true
      }
    } else {
      app.setStep(next, room: Self.room)
    }
    scheduleAutoHint()
  }

  /// When the room resumes past Try it, the flag shows the rolls the design compares.
  private static var exampleRolls: [MarbleRoll] {
    [20.0, 50.0].map { MarbleRoll(track: MarbleTrack(angle: $0, start: .star), landedAt: .distantPast) }
  }

  func announce(_ text: String) {
    guard !text.isEmpty else { return }
    AccessibilityNotification.Announcement(text).post()
  }

  // MARK: Scene

  /// What the garden shows on this step.
  var scene: MarbleSceneState {
    var scene = MarbleSceneState()
    scene.rolling = rolling
    scene.trail = trail
    scene.labelPulse = labelPulse
    switch step {
    case .checkpoint1, .why:
      let compared = comparedTracks
      scene.ramps = [RampMark(track: compared.gentle, isGhost: true), RampMark(track: compared.steep)]
      if step == .checkpoint1 {
        scene.restingMarbles = [compared.gentle.startCenter, compared.steep.startCenter]
        scene.trail = []
      } else {
        scene.restingMarbles = [compared.steep.restCenter]
        scene.callouts = [MarbleCallouts.sameHeight, .quickSlow, .sameDrop][min(whyBeat, 2)]
        scene.lumiMood = .happy
        scene.trail = []
      }
    case .tryIt, .check:
      let main = MarbleTrack(angle: rampAngle, start: .star)
      scene.ramps = ghostRamp(for: main, rolls: tryRolls) + [RampMark(track: main)]
      scene.flags = FlagMark.marks(for: tryRolls)
      if rolling.isEmpty {
        scene.restingMarbles = [tryRolls.last?.track.restCenter ?? main.startCenter]
      }
      if step == .check {
        scene.lumiMood = checkOutcome == .right ? .happy : (checkOutcome == nil ? .wonder : .calm)
      }
      scene.accessibilityValue = tryRolls.count > 1 && scene.flags.count == 1
        ? "Both marbles stopped at the same flag."
        : tryRolls.last.map { "The marble stopped at the flag, from a \(Int($0.track.angle))° ramp." } ?? "A \(Int(rampAngle))° ramp. The marble waits at the star."
    case .checkpoint2, .challenge, .solved:
      let main = MarbleTrack(angle: rampAngle, start: .top)
      scene.showsStarLine = false
      scene.ramps = ghostRamp(for: main, rolls: challengeRolls) + [RampMark(track: main)]
      scene.flags = step == .checkpoint2 ? [] : FlagMark.marks(for: challengeRolls.filter { !$0.track.reachesCup })
      if step == .checkpoint2 { scene.trail = [] }
      if rolling.isEmpty {
        scene.restingMarbles = [step == .challenge || step == .solved ? (challengeRolls.last?.track.restCenter ?? main.startCenter) : main.startCenter]
      }
      scene.flowerOpen = step == .solved
      scene.lumiMood = step == .solved ? .happy : .wonder
      scene.accessibilityValue = step == .solved
        ? "The marble rolled into the flower and the firefly woke up."
        : challengeRolls.last.map { _ in "The marble stopped short of the flower, from a \(Int(rampAngle))° ramp." } ?? "A \(Int(rampAngle))° ramp. The marble waits at the very top."
    default:
      break
    }
    if scene.accessibilityValue.isEmpty {
      scene.accessibilityValue = "A \(Int(rampAngle))° ramp."
    }
    return scene
  }

  /// The previous roll’s ramp, if it was tilted differently.
  private func ghostRamp(for main: MarbleTrack, rolls: [MarbleRoll]) -> [RampMark] {
    guard let earlier = rolls.last(where: { abs($0.track.angle - main.angle) > 2 }) else { return [] }
    return [RampMark(track: MarbleTrack(angle: earlier.track.angle, start: main.start), isGhost: true)]
  }
}

/// A roll that has finished: its ramp and when its marble landed.
struct MarbleRoll: Identifiable, Equatable {
  let id = UUID()
  var track: MarbleTrack
  var landedAt: Date
}

/// A marble rolling right now.
struct RollingMarble: Identifiable, Equatable {
  let id = UUID()
  var track: MarbleTrack
  var plan: RollPlan
  var startedAt: Date
}
