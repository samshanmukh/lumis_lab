import SwiftUI

/// The words and choices for each scene step (1.3 to 1.7). The scene itself stays put;
/// only this layer changes between steps, with the step motion.
struct MirrorStepPanel: View {
  var room: MirrorRoomModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ProgressDots(current: room.step.progressIndex)
        .padding(.bottom, 26)

      content
        .id(room.step)
        .transition(stepTransition)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var stepTransition: AnyTransition {
    if reduceMotion { return .opacity }
    return .asymmetric(
      insertion: .opacity.combined(with: .offset(y: 12)),
      removal: .opacity.animation(.easeOut(duration: 0.18))
    )
  }

  @ViewBuilder
  private var content: some View {
    switch room.step {
    case .tryIt: tryIt
    case .check: count
    case .why: why
    case .challenge: challenge
    case .solved: solved
    default: EmptyView()
    }
  }

  // MARK: 1.3 Try it

  private var tryIt: some View {
    VStack(alignment: .leading, spacing: 12) {
      title("Fold to 90°")
      Text(room.heldAtGoal
        ? "That’s 90°. Hold still and count every Lumi, the real one too."
        : "Close your phone like a book. Stop when the mirrors reach the gold dashes.")
        .font(LabFont.body)
        .foregroundStyle(LabColor.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: room.heldAtGoal)
    }
  }

  // MARK: 1.4 Count

  private var count: some View {
    VStack(alignment: .leading, spacing: 0) {
      title("How many Lumis?")

      HStack(spacing: 12) {
        ForEach(2...6, id: \.self) { value in
          ChoiceChip(
            title: "\(value)",
            outline: .circle(56),
            mark: countMark(for: value),
            isLocked: room.countOutcome == .right || room.countOutcome == .revealed
          ) {
            room.answerCount(value)
          }
        }
      }
      .padding(.top, 22)
      .accessibilityElement(children: .contain)
      .accessibilityLabel("How many Lumis?")

      if let outcome = room.countOutcome {
        countFeedback(outcome)
          .padding(.top, 20)
          .transition(.opacity)
      }

      if room.countOutcome == .right || room.countOutcome == .revealed {
        Text("\(Text("1 real Lumi").foregroundStyle(LabColor.label)) + 3 reflections \(Text("= 4").foregroundStyle(LabColor.correct))")
          .font(.system(.title3, design: .rounded, weight: .semibold))
          .foregroundStyle(LabColor.primaryInk)
          .padding(.top, 16)
          .transition(.opacity.combined(with: .offset(y: 8)))
          .accessibilityLabel("1 real Lumi plus 3 reflections equals 4")
      }
    }
    .animation(.easeOut(duration: 0.2), value: room.countOutcome)
  }

  private func countMark(for value: Int) -> ChoiceChip.Mark {
    switch room.countOutcome {
    case .right where room.countPick == value: .right
    case .wrong where room.countPick == value: .wrong
    case .revealed where value == MirrorRoomModel.rightCount: .revealed
    default: .rest
    }
  }

  @ViewBuilder
  private func countFeedback(_ outcome: CountOutcome) -> some View {
    switch outcome {
    case .right:
      Label(room.countResultLine, systemImage: "checkmark")
        .foregroundStyle(LabColor.correct)
        .font(.system(.body, design: .rounded, weight: .medium))
        .accessibilityElement(children: .combine)
    case .wrong:
      Label("Not quite. Count again, the real one too.", systemImage: "arrow.counterclockwise")
        .foregroundStyle(LabColor.retry)
        .font(.system(.body, design: .rounded, weight: .medium))
        .accessibilityElement(children: .combine)
    case .revealed:
      Text("It’s 4. Let’s see why.")
        .foregroundStyle(LabColor.primaryInk)
        .font(.system(.body, design: .rounded, weight: .medium))
    }
  }

  // MARK: 1.5 Why

  private static let beats: [(title: String, body: String)] = [
    ("One mirror, one reflection", "Each mirror shows Lumi once, like a coin held up to a hand mirror. Two mirrors, so two reflections."),
    ("Mirrors reflect each other", "Each mirror also reflects the other one’s reflection. That makes one more Lumi behind the corner: its light bounces off both mirrors."),
    ("Closer mirrors, more Lumis", "Close the mirrors and light bounces between them more times, so more reflections fit. One Lumi per slice: 4 at 90°, 6 at 60°.")
  ]

  private var why: some View {
    let beat = Self.beats[room.whyBeat]
    return VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        title(beat.title)
        Text(beat.body)
          .font(LabFont.body)
          .foregroundStyle(LabColor.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
      }
      .id(room.whyBeat)
      .transition(stepTransition)

      WhyPager(beat: room.whyBeat, count: Self.beats.count) { room.setBeat($0) }
        .padding(.top, 18)

      if room.whyBeat == 2 {
        Text("\(Text("In real life:").bold()) stand two hand mirrors like an open book and put a coin between them. Close them and count the coins.")
          .font(.system(.subheadline, design: .rounded))
          .foregroundStyle(LabColor.label)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 22)
          .transition(.opacity)
      }
    }
  }

  // MARK: 1.6 Challenge

  private var challenge: some View {
    VStack(alignment: .leading, spacing: 12) {
      title("Make 6 Lumis")
      Text(room.challengeStatus)
        .font(LabFont.body)
        .foregroundStyle(room.challengeOvershot ? LabColor.retry : LabColor.label)
        .contentTransition(.numericText())
        .animation(.snappy, value: room.challengeCount)
        .accessibilityAddTraits(.updatesFrequently)
    }
  }

  // MARK: 1.7 Solved

  private var solved: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("6 Lumis!")
        .font(LabFont.display)
        .foregroundStyle(LabColor.primaryInk)
        .accessibilityAddTraits(.isHeader)
      Text("1 real Lumi + 5 reflections. Lumi isn’t alone anymore.")
        .font(LabFont.body)
        .foregroundStyle(LabColor.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)
      FireflyRow(earned: room.app.mirror.fireflies)
        .padding(.top, 14)
    }
  }

  private func title(_ text: String) -> some View {
    Text(text)
      .font(LabFont.title)
      .foregroundStyle(LabColor.primaryInk)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader)
  }
}

/// Three beats: the current one is a lemon pill. One adjustable accessibility element.
private struct WhyPager: View {
  var beat: Int
  var count: Int
  var select: (Int) -> Void

  var body: some View {
    HStack(spacing: 6) {
      ForEach(0..<count, id: \.self) { index in
        Capsule()
          .fill(index == beat ? LabColor.label : .white.opacity(0.3))
          .frame(width: index == beat ? 16 : 5, height: 5)
      }
    }
    .frame(minHeight: 20)
    .contentShape(Rectangle())
    .accessibilityElement()
    .accessibilityLabel("Why")
    .accessibilityValue("\(beat + 1) of \(count)")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: select(beat + 1)
      case .decrement: select(beat - 1)
      @unknown default: break
      }
    }
  }
}
