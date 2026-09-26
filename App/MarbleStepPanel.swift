import SwiftUI

/// The flat half of the Marble Ramp: the words, the ramp readout, the choices and the forward
/// step, 40 pt from the bottom. Only this layer changes between steps; the garden stays put.
struct MarbleStepPanel: View {
  var room: MarbleRampModel
  var celebrationDone: Bool
  var showMath: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      content
        .id(room.step)
        .transition(stepTransition)
      Spacer(minLength: 24)
      actions
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .animation(reduceMotion ? LabMotion.reduced : LabMotion.step, value: room.readyToAsk)
    .animation(reduceMotion ? LabMotion.reduced : LabMotion.step, value: room.checkOutcome)
    .animation(reduceMotion ? LabMotion.reduced : LabMotion.step, value: celebrationDone)
  }

  private var stepTransition: AnyTransition {
    if reduceMotion { return .opacity }
    return .asymmetric(
      insertion: .opacity.combined(with: .offset(y: 12)),
      removal: .opacity.animation(.easeOut(duration: 0.18))
    )
  }

  private var rise: AnyTransition {
    reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12))
  }

  @ViewBuilder
  private var content: some View {
    switch room.step {
    case .tryIt:
      VStack(alignment: .leading, spacing: 0) {
        title("Tilt the screen, then roll")
        readout(status: room.tryItStatus)
      }
    case .check:
      check
    case .why:
      why
    case .challenge:
      VStack(alignment: .leading, spacing: 0) {
        title("Wake the firefly")
        line("Now the marble starts at the very top.")
        readout(status: room.challengeStatus)
      }
    case .solved:
      VStack(alignment: .leading, spacing: 12) {
        title("The firefly woke up!")
        line("A steeper ramp lifted the start higher, so the marble rolled farther.")
        FireflyRow(earned: room.app.room(MarbleRampModel.room).fireflies)
          .padding(.top, 10)
      }
    default:
      EmptyView()
    }
  }

  // MARK: Readout

  /// The ramp angle is the number used: big, with the dial in its place when there’s no hinge.
  private func readout(status: String?) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      if room.usesDial {
        AngleDial(hinge: room.hinge, scale: .rampTilt)
          .disabled(room.isRolling || room.isDemoPlaying)
          .opacity(room.isDemoPlaying ? 0.45 : 1)
          .padding(.top, 18)
      } else {
        Text("\(Int(room.rampAngle))°")
          .font(.system(size: 56, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(LabColor.primaryInk)
          .contentTransition(.numericText(value: room.rampAngle))
          .animation(.snappy, value: room.rampAngle)
          .padding(.top, 14)
          .accessibilityLabel("Ramp angle")
          .accessibilityValue("\(Int(room.rampAngle)) degrees")
          .accessibilityAddTraits(.updatesFrequently)
      }
      Text("ramp angle")
        .font(LabFont.caption)
        .foregroundStyle(LabColor.tertiaryInk)
        .padding(.leading, 4)
        .padding(.top, room.usesDial ? 8 : 0)
        .accessibilityHidden(true)
      if let status, !status.isEmpty {
        Text(status)
          .font(.system(.subheadline, design: .rounded, weight: .medium))
          .foregroundStyle(LabColor.label)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.leading, 4)
          .padding(.top, 10)
          .contentTransition(.opacity)
          .animation(.easeInOut(duration: 0.2), value: status)
      }
    }
  }

  // MARK: 3.4 Check

  private var check: some View {
    VStack(alignment: .leading, spacing: 0) {
      title("Which rolled farther?")
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 12) { checkChips }
        VStack(alignment: .leading, spacing: 12) { checkChips }
      }
      .padding(.top, 22)
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Which rolled farther?")

      if let feedback = room.checkFeedback {
        Group {
          switch room.checkOutcome {
          case .right:
            Label(feedback, systemImage: "checkmark")
              .foregroundStyle(LabColor.correct)
          case .wrong:
            Label(feedback, systemImage: "arrow.counterclockwise")
              .foregroundStyle(LabColor.retry)
          default:
            Text(feedback)
              .foregroundStyle(LabColor.primaryInk)
          }
        }
        .font(.system(.body, design: .rounded, weight: .medium))
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .padding(.top, 20)
        .transition(.opacity)
      }
    }
  }

  private var checkChips: some View {
    ForEach(MarbleRampModel.rampChoices, id: \.choice) { option in
      ChoiceChip(
        title: option.title,
        outline: .capsule,
        mark: checkMark(for: option.choice),
        isLocked: room.checkOutcome == .right || room.checkOutcome == .revealed
      ) {
        room.answerCheck(option.choice)
      }
    }
  }

  private func checkMark(for choice: CheckpointChoice) -> ChoiceChip.Mark {
    switch room.checkOutcome {
    case .right where room.checkPick == choice: .right
    case .wrong where room.checkPick == choice: .wrong
    case .revealed where choice == .option("same"): .revealed
    default: .rest
    }
  }

  // MARK: 3.5 Why

  private static let beats: [(title: String, body: String)] = [
    ("Height is stored-up speed", "Lifting the marble to the star line stores up energy. As it rolls down, that height turns into speed. The higher it starts, the faster it ends up."),
    ("Steep is quicker, not faster", "Gravity pulls harder along a steep ramp, so the marble gets its speed sooner. A gentle ramp takes longer, but the same drop gives the same speed at the bottom."),
    ("Same speed, same stop", "Both marbles leave the ramp just as fast, so the path slows them down over the same distance. That’s why they stop at the same flag.")
  ]

  private var why: some View {
    let beat = Self.beats[room.whyBeat]
    return VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        title(beat.title)
        line(beat.body)
      }
      .id(room.whyBeat)
      .transition(stepTransition)

      WhyPager(beat: room.whyBeat, count: Self.beats.count) { room.setBeat($0) }
        .padding(.top, 18)

      if room.whyBeat == 2 {
        Text("\(Text("In real life:").bold()) a roller coaster’s top speed comes from how high its first hill is, not how steep.")
          .font(.system(.subheadline, design: .rounded))
          .foregroundStyle(Color(red: 1, green: 227 / 255, blue: 166 / 255))
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 22)
          .transition(.opacity)
      }
    }
  }

  // MARK: Actions

  @ViewBuilder
  private var actions: some View {
    HStack(spacing: 12) {
      switch room.step {
      case .tryIt:
        if room.readyToAsk {
          PrimaryLabButton(title: "What happened?", fillsWidth: false) { room.whatHappened() }
            .transition(rise)
          QuietLabButton(title: "Roll again") { room.roll() }
        } else {
          PrimaryLabButton(title: "Roll", fillsWidth: false) { room.roll() }
          QuietLabButton(title: "Show me") { room.showMeBothRolls() }
        }
      case .check:
        if room.checkOutcome == .right || room.checkOutcome == .revealed {
          PrimaryLabButton(title: "Why?", fillsWidth: false) { room.startWhy() }
            .transition(rise)
        }
      case .why:
        PrimaryLabButton(title: "Next", fillsWidth: false) { room.nextBeat() }
        if room.whyBeat == 2 {
          QuietLabButton(title: "Show the math", systemImage: "sum", action: showMath)
            .transition(.opacity)
        }
      case .challenge:
        PrimaryLabButton(title: "Roll", fillsWidth: false) { room.roll() }
      case .solved:
        if celebrationDone {
          PrimaryLabButton(title: "Next: \(RoomID.launchAngle.title)", fillsWidth: false) { room.finishRoom() }
            .transition(rise)
        }
      default:
        EmptyView()
      }
    }
  }

  private func title(_ text: String) -> some View {
    Text(text)
      .font(LabFont.title)
      .foregroundStyle(LabColor.primaryInk)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader)
  }

  private func line(_ text: String) -> some View {
    Text(text)
      .font(LabFont.body)
      .foregroundStyle(LabColor.secondaryInk)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, 10)
  }
}
