import SwiftUI
import Observation

/// The Glass Pond’s flow, played like a laptop: the hinge tilts Lumi’s light at the pond’s
/// surface. Checkpoints, the tilt, what happened, the why beats and the crystal vine.
@MainActor
@Observable
final class GlassPondModel: CheckpointRoom {
  static let id: RoomID = .glassPond
  /// The fixed scenes: checkpoint 1 shows light getting out, checkpoint 2 the vine leaking.
  static let checkpointOneTilt = 25.0
  static let checkpointTwoTilt = 35.0
  /// Why is frozen per beat: bent at 25°, skimming at 41.7°, stuck at 48°.
  static let whyTilts: [Double] = [25, 41.7, 48]
  static let whyBeats = 3
  static let solvedTilt = 50.0

  let app: AppModel
  let hinge: HingeModel

  private(set) var step: RoomStep
  private(set) var checkpoint = CheckpointState()

  /// Try it: the tilt has passed 42° once (or Show me has shown it), so What happened? stays.
  private(set) var crossedCritical = false
  /// A sweep or demo drives the scene instead of the hinge while it plays.
  private(set) var demoTilt: Double?
  private(set) var isSweeping = false

  private(set) var checkPick: PondChoice?
  private(set) var checkOutcome: CountOutcome?
  private(set) var checkWrongTries = 0
  private(set) var worried = false

  private(set) var whyBeat = 0
  var showingMath = false

  private(set) var winTilt: Double?

  private(set) var hint: HintState?
  private var hintLevels: [RoomStep: Int] = [:]
  private var autoHintShown = false

  private(set) var successTick = 0
  private(set) var softTick = 0
  private(set) var selectionTick = 0
  private(set) var flarePulse = 0

  private var lightZone: ZoneTracker
  private var challengeZone: ZoneTracker
  private var sweepTask: Task<Void, Never>?
  private var holdTask: Task<Void, Never>?
  private var moodTask: Task<Void, Never>?
  private var yourTurnTask: Task<Void, Never>?
  private var autoHintTask: Task<Void, Never>?

  init(app: AppModel, hinge: HingeModel) {
    self.app = app
    self.hinge = hinge
    let saved = app.room(Self.id).step
    step = saved == .door || saved == .roomEnd ? .checkpoint1 : saved
    let tilt = GlassOptics.tilt(forHinge: hinge.angle)
    lightZone = ZoneTracker(lines: [GlassOptics.criticalAngle], value: tilt)
    challengeZone = ZoneTracker(lines: [GlassOptics.almostStart, GlassOptics.criticalAngle], value: tilt)
    if step == .check || step == .why { crossedCritical = true }
  }

  var state: RoomState { app.room(Self.id) }

  // MARK: Scene

  var liveTilt: Double { GlassOptics.tilt(forHinge: hinge.angle) }

  var sceneTilt: Double {
    switch step {
    case .checkpoint1: Self.checkpointOneTilt
    case .checkpoint2: Self.checkpointTwoTilt
    case .why: Self.whyTilts[whyBeat]
    case .solved: winTilt ?? Self.solvedTilt
    default: demoTilt ?? liveTilt
    }
  }

  var isLive: Bool { step == .tryIt || step == .check || step == .challenge }
  var usesDial: Bool { isLive && hinge.usesDial }
  var showsVine: Bool { step == .checkpoint2 || step == .challenge || step == .solved }

  var sceneLight: PondLight { GlassOptics.light(forTilt: sceneTilt) }

  var sceneMood: LumiMood {
    switch step {
    case .check:
      if worried { return .worried }
      return checkOutcome == .right ? .happy : .wonder
    case .why: return .calm
    case .solved: return .happy
    default: return .wonder
    }
  }

  /// The scene as one accessibility element, in plain words.
  var sceneValue: String {
    guard showsVine else { return sceneLight.sceneValue }
    if step == .solved { return "Light reaches the lily" }
    switch challengeZone.zone {
    case 2: return "Light reaches the lily"
    case 1: return "Light almost stays in"
    default: return "Light escapes at the first bounce"
    }
  }

  /// The label under the readout: what happened at the surface, once it has happened.
  var tryItStatus: String? {
    guard crossedCritical else { return nil }
    return lightZone.zone == 1 ? "Stuck! The light can’t get out." : "It gets out."
  }

  var isAlmost: Bool { step == .challenge && challengeZone.zone == 1 }

  // MARK: Checkpoints

  var checkpointQuestion: CheckpointQuestion {
    if step == .checkpoint1 {
      return CheckpointQuestion(
        title: "If Lumi tilts more…",
        detail: "What happens to her light at the surface?",
        options: PondChoice.checkpointOne.map { CheckpointOption(choice: $0.checkpointChoice, title: $0.title, outline: .capsule) }
      )
    }
    return CheckpointQuestion(
      title: "To keep the light inside the vine, tilt it…",
      options: PondChoice.checkpointTwo.map { CheckpointOption(choice: $0.checkpointChoice, title: $0.title, outline: .capsule) }
    )
  }

  var checkpointForwardTitle: String { step == .checkpoint1 ? "Next" : "Next: The Marble Ramp" }

  var checkpointFeedback: String? {
    switch (step, checkpoint.outcome) {
    case (.checkpoint1, .right): "Yes! Tilt far enough and the light can’t get out."
    case (.checkpoint2, .right): "Yes! Past 42°, the surface works like a mirror."
    case (_, .wrong): "Not quite. Want to see it?"
    case (_, .notSure): "That’s okay. Want to see it?"
    default: nil
    }
  }

  func answer(_ choice: CheckpointChoice) {
    guard checkpoint.outcome == nil else { return }
    let isFirst = step == .checkpoint1
    let right: CheckpointChoice = isFirst ? PondChoice.getsStuck.checkpointChoice : PondChoice.past42.checkpointChoice
    let outcome: CheckpointOutcome = choice == .notSure ? .notSure : (choice == right ? .right : .wrong)

    withAnimation(.easeOut(duration: 0.2)) {
      checkpoint = CheckpointState(picked: choice, outcome: outcome)
    }
    app.updateRoom(Self.id) { state in
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

  /// Next (after a right answer) or Skip: checkpoint 2 after the first, the room’s end after the second.
  func checkpointForward() {
    go(to: step == .checkpoint1 ? .checkpoint2 : .roomEnd)
  }

  var seeItDestination: RoomStep { step == .checkpoint1 ? .tryIt : .challenge }

  /// The guess from checkpoint 1, so the check can compare with it.
  var guess: PondChoice? {
    state.checkpoints[1].flatMap(PondChoice.init(savedValue:))
  }

  // MARK: Try it

  /// Show me: a guided sweep from 20° to 50° over 4 s, then the student’s own angle again.
  /// Passing 42° on the way counts, so What happened? appears.
  func showMe() {
    if isSweeping {
      stopSweep()
      return
    }
    closeHint()
    announce("Showing you. Tilting from 20 to 50 degrees.")
    sweepTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await self.sweep(from: 20, to: 50, over: .seconds(4))
      guard !Task.isCancelled else { return }
      self.handBack()
    }
  }

  private func stopSweep() {
    sweepTask?.cancel()
    handBack()
  }

  func whatHappened() {
    go(to: .check)
  }

  // MARK: Check

  func answerCheck(_ choice: PondChoice) {
    guard checkOutcome != .right, checkOutcome != .revealed else { return }
    checkPick = choice
    if choice == .gotStuck {
      withAnimation(.easeOut(duration: 0.2)) { checkOutcome = .right }
      successTick += 1
      app.updateRoom(Self.id) { $0.fireflies.insert(.answer) }
      announce("Correct. The light got stuck.")
      return
    }

    checkWrongTries += 1
    app.updateRoom(Self.id) { $0.wrongTries += 1 }
    softTick += 1
    if checkWrongTries >= 2 {
      withAnimation(.easeOut(duration: 0.2)) {
        checkOutcome = .revealed
        checkPick = .gotStuck
      }
      announce("The light got stuck. Let’s find out why.")
    } else {
      withAnimation(.easeOut(duration: 0.2)) { checkOutcome = .wrong }
      announce("Not quite. Watch the surface as you tilt.")
      startWorried()
    }
  }

  var checkFeedback: String? {
    switch checkOutcome {
    case .right:
      let line = "Yes! Past 42°, the light can’t get out, so it bounces back inside."
      return guess == .getsStuck ? line + " Just like you guessed." : line
    case .wrong: return "Not quite. Watch the surface as you tilt."
    case .revealed: return "It got stuck. Let’s find out why."
    case nil: return nil
    }
  }

  private func startWorried() {
    moodTask?.cancel()
    worried = true
    moodTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(1200))
      guard let self, !Task.isCancelled else { return }
      withAnimation(.easeInOut(duration: 0.2)) { self.worried = false }
    }
  }

  func startWhy() {
    go(to: .why)
  }

  // MARK: Why

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

  func finishRoom() {
    go(to: .roomEnd)
  }

  // MARK: Angle input

  /// Call on every hinge or dial update, during a sweep, and after each step change.
  func angleChanged() {
    guard isLive else { return }
    let tilt = sceneTilt

    if lightZone.update(tilt) {
      selectionTick += 1
      flarePulse += 1
    }
    switch step {
    case .tryIt:
      if lightZone.zone == 1, !crossedCritical {
        withAnimation(LabMotion.step) { crossedCritical = true }
        announce("Stuck. The light can’t get out. What happened is available.")
      }
    case .challenge:
      updateChallenge(tilt)
    default:
      break
    }
  }

  private func updateChallenge(_ tilt: Double) {
    guard challengeZone.update(tilt) else { return }
    if !isDemoPlaying {
      announce(sceneValue)
      scheduleAutoHint()
    }
    armWin()
  }

  /// Tilt ≥ 41.8° held for 0.3 s wins. No button: the fold is the answer, and a demo never wins.
  private func armWin(after hold: Duration = .milliseconds(300)) {
    holdTask?.cancel()
    guard step == .challenge, challengeZone.zone == 2, !isDemoPlaying else { return }
    holdTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: hold)
      guard let self, !Task.isCancelled, self.step == .challenge, !self.isDemoPlaying,
            GlassOptics.isStuck(self.sceneTilt) else { return }
      self.win()
    }
  }

  private func win() {
    winTilt = max(sceneTilt, GlassOptics.criticalAngle)
    app.updateRoom(Self.id) { $0.fireflies.insert(.challenge) }
    successTick += 1
    go(to: .solved)
    announce("The moon lily woke up. Room complete, \(state.fireflies.count) of 3 fireflies.")
  }

  // MARK: Steps

  func go(to next: RoomStep) {
    // With the dial, Try it and the challenge start where their design does (light out at 25°,
    // leaking at 35°), so the student makes the crossing themselves.
    if hinge.usesDial {
      if next == .tryIt, liveTilt >= GlassOptics.skimStart {
        hinge.setDialAngle(GlassOptics.hinge(forTilt: Self.checkpointOneTilt), animation: .easeInOut(duration: 0.6))
      } else if next == .challenge, liveTilt >= GlassOptics.almostStart {
        hinge.setDialAngle(GlassOptics.hinge(forTilt: Self.checkpointTwoTilt), animation: .easeInOut(duration: 0.6))
      }
    }
    holdTask?.cancel()
    moodTask?.cancel()
    sweepTask?.cancel()
    yourTurnTask?.cancel()
    withAnimation(LabMotion.step) {
      step = next
      hint = nil
      demoTilt = nil
      isSweeping = false
      worried = false
      showingMath = false
      if next.isCheckpoint { checkpoint = CheckpointState() }
      if next == .tryIt { crossedCritical = false }
      if next == .check {
        checkPick = nil
        checkOutcome = nil
        checkWrongTries = 0
      }
      if next == .why { whyBeat = 0 }
      if next != .solved { winTilt = nil }
    }
    lightZone = ZoneTracker(lines: [GlassOptics.criticalAngle], value: sceneTilt)
    challengeZone = ZoneTracker(lines: [GlassOptics.almostStart, GlassOptics.criticalAngle], value: sceneTilt)
    if next == .roomEnd {
      app.updateRoom(Self.id) { state in
        state.step = .roomEnd
        state.solved = true
      }
    } else {
      app.setStep(next, room: Self.id)
    }
    angleChanged()
    // A tilt already past the tipping point wins too, once the light has had a moment to reach the lily.
    armWin(after: .milliseconds(1200))
    scheduleAutoHint()
  }

  // MARK: Sweeps and demos

  /// Drives the scene from one tilt to another, so the readout counts and 42° is crossed on the way.
  private func sweep(from start: Double, to end: Double, over duration: Duration) async {
    isSweeping = true
    withAnimation(.easeInOut(duration: 0.3)) { demoTilt = start }
    angleChanged()
    try? await Task.sleep(for: .milliseconds(300))
    let clock = ContinuousClock()
    let began = clock.now
    let total = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    while !Task.isCancelled {
      let elapsed = clock.now - began
      let fraction = min(1, (Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18) / total)
      demoTilt = start + (end - start) * fraction
      angleChanged()
      if fraction >= 1 { break }
      try? await Task.sleep(for: .milliseconds(16))
    }
  }

  /// The student’s own angle comes back, eased so the scene never jumps.
  private func handBack() {
    isSweeping = false
    withAnimation(.easeInOut(duration: 0.3)) { demoTilt = nil }
    lightZone = ZoneTracker(lines: [GlassOptics.criticalAngle], value: liveTilt)
    challengeZone = ZoneTracker(lines: [GlassOptics.almostStart, GlassOptics.criticalAngle], value: liveTilt)
    angleChanged()
    armWin()
  }

  // MARK: Hints

  var hintContent: HintContent? { Self.hintContent(for: step) }
  var isDemoPlaying: Bool { hint?.phase == .showing }
  /// Level 2 marks the place in the scene where it matters.
  var hintMarksScene: Bool { hint?.level == 2 && hint?.phase == .panel }

  func toggleHint() {
    if hint != nil {
      closeHint()
    } else {
      openHint()
    }
  }

  func openHint() {
    guard let content = hintContent else { return }
    if isSweeping { stopSweep() }
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
    if isDemoPlaying {
      sweepTask?.cancel()
      handBack()
    }
    yourTurnTask?.cancel()
    withAnimation(.easeIn(duration: 0.2)) { hint = nil }
  }

  /// Level 3: Lumi shows it once (4 s), then hands the student’s angle back.
  func showMeFromHint() {
    guard hint != nil, !isDemoPlaying else { return }
    sweepTask?.cancel()
    holdTask?.cancel()
    withAnimation(.spring(duration: 0.3, bounce: 0.1)) { hint?.phase = .showing }
    sweepTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await self.playDemo()
      guard !Task.isCancelled else { return }
      self.handBack()
      self.showYourTurn()
    }
  }

  /// Stop ends the demo early and hands back the student’s own angle.
  func stopDemo() {
    guard isDemoPlaying else { return }
    sweepTask?.cancel()
    handBack()
    showYourTurn()
  }

  private func playDemo() async {
    let start = ContinuousClock.now
    switch step {
    case .tryIt:
      announce("Showing you. Tilting from 25 to 55 degrees.")
      await sweep(from: 25, to: 55, over: .milliseconds(3400))
    case .check:
      announce("Showing you your tilt again, from 25 to 55 degrees.")
      await sweep(from: 25, to: 55, over: .milliseconds(3400))
    case .challenge:
      announce("Showing you. Tilting to 46 degrees.")
      let own = liveTilt
      await sweep(from: own, to: 46, over: .milliseconds(1400))
      try? await Task.sleep(for: .milliseconds(1200))
      guard !Task.isCancelled else { return }
      await sweep(from: 46, to: own, over: .milliseconds(1000))
    default:
      break
    }
    try? await Task.sleep(until: start + .seconds(4), clock: .continuous)
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
        "Tilt the screen slowly.",
        "Keep going until the beam leans past 42°.",
        "Lumi can tilt the beam from 25° to 55° for you. Then the phone is yours again."
      ], showMeTitle: "Show me")
    case .check:
      HintContent(levels: [
        "Think about what the light did past 42°.",
        "Look at the surface: did the light cross it, or bounce off it?",
        "Lumi can replay your tilt, from 25° to 55°. Watch the surface."
      ], showMeTitle: "Show me again")
    case .challenge:
      HintContent(levels: [
        "Keep Lumi’s light inside the vine.",
        "Tilt past 42°, like before. Then the light bounces off the vine’s walls instead of escaping.",
        "Watch Lumi do it once. Then the phone is yours again, at the angle you had."
      ], showMeTitle: "Show me")
    case .why:
      HintContent(levels: ["Read the words, then find them in the picture."], showMeTitle: nil)
    case .solved:
      HintContent(levels: ["The moon lily is awake. Tap Next when you’re ready."], showMeTitle: nil)
    default:
      nil
    }
  }

  func announce(_ text: String) {
    guard !text.isEmpty else { return }
    AccessibilityNotification.Announcement(text).post()
  }
}

/// The Glass Pond’s answers. Checkpoint 1 is saved as the room’s guess.
enum PondChoice: String, CaseIterable {
  case getsOutEasier
  case getsStuck
  case noChange
  case gotOutEasier
  case gotStuck
  case gotNoChange
  case under42
  case past42

  init?(savedValue: String) {
    self.init(rawValue: savedValue)
  }

  var title: String {
    switch self {
    case .getsOutEasier: "It gets out easier"
    case .getsStuck: "It gets stuck"
    case .noChange, .gotNoChange: "No change"
    case .gotOutEasier: "It got out easier"
    case .gotStuck: "It got stuck"
    case .under42: "Under 42°"
    case .past42: "Past 42°"
    }
  }

  var checkpointChoice: CheckpointChoice { .option(rawValue) }

  static let checkpointOne: [PondChoice] = [.getsOutEasier, .getsStuck, .noChange]
  static let check: [PondChoice] = [.gotOutEasier, .gotStuck, .gotNoChange]
  static let checkpointTwo: [PondChoice] = [.under42, .past42]
}
