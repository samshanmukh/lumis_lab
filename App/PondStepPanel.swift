import SwiftUI

/// The words and controls for each Glass Pond scene step (2.3 to 2.7). The scene stays put;
/// only this layer changes between steps, with the step motion. The forward step sits at the foot.
struct PondStepPanel: View {
  var room: GlassPondModel
  var celebrationDone: Bool
  var showMath: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ScaledMetric(relativeTo: .largeTitle) private var readoutSize: CGFloat = 56

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ScrollView {
        content
          .id(room.step)
          .transition(stepTransition)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollBounceBehavior(.basedOnSize)

      actions
        .padding(.top, 12)
    }
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
    case .check: check
    case .why: why
    case .challenge: challenge
    case .solved: solved
    default: EmptyView()
    }
  }

  // MARK: 2.3 Try it

  private var tryIt: some View {
    VStack(alignment: .leading, spacing: 12) {
      title(room.usesDial ? "Tilt the light" : "Tilt the screen")
      if room.usesDial {
        Text("Or stand the phone up like a laptop.")
          .font(LabFont.body)
          .foregroundStyle(LabColor.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
      }
      angleControl(status: room.tryItStatus)
        .padding(.top, room.usesDial ? 10 : 4)
    }
  }

  // MARK: 2.4 Check

  private var check: some View {
    VStack(alignment: .leading, spacing: 0) {
      title("What happened?")

      ChipFlow(spacing: 12) { checkChoices }
        .padding(.top, 18)
      .accessibilityElement(children: .contain)
      .accessibilityLabel("What happened?")

      if let feedback = room.checkFeedback, let outcome = room.checkOutcome {
        Label(feedback, systemImage: outcome == .wrong ? "arrow.counterclockwise" : "checkmark")
          .font(.system(.body, design: .rounded, weight: .medium))
          .foregroundStyle(outcome == .wrong ? LabColor.retry : LabColor.correct)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 16)
          .transition(.opacity)
          .accessibilityElement(children: .combine)
      }
    }
    .animation(.easeOut(duration: 0.2), value: room.checkOutcome)
  }

  private var checkChoices: some View {
    ForEach(PondChoice.check, id: \.self) { choice in
      ChoiceChip(
        title: choice.title,
        outline: .capsule,
        mark: checkMark(for: choice),
        isLocked: room.checkOutcome == .right || room.checkOutcome == .revealed
      ) {
        room.answerCheck(choice)
      }
    }
  }

  private func checkMark(for choice: PondChoice) -> ChoiceChip.Mark {
    switch room.checkOutcome {
    case .right where room.checkPick == choice: .right
    case .wrong where room.checkPick == choice: .wrong
    case .revealed where choice == .gotStuck: .revealed
    default: .rest
    }
  }

  // MARK: 2.5 Why

  private static let beats: [(title: String, body: String)] = [
    ("Light bends as it leaves glass", "Light travels slower in glass than in air. When it crosses out at a slant, it speeds up and swings away from straight up, like a wagon rolling from grass onto a sidewalk."),
    ("More tilt, more bend", "Tilt the light more and it bends even more. At about 42° it bends so far that it can only skim along the surface."),
    ("Past 42°, the surface is a mirror", "Any steeper and there’s no way out, so all the light bounces back inside the glass. Scientists call this total internal reflection.")
  ]

  private var why: some View {
    let beat = Self.beats[room.whyBeat]
    return VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        title(beat.title)
        Text(beat.body)
          .font(LabFont.body)
          .foregroundStyle(LabColor.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
      }
      .id(room.whyBeat)
      .transition(stepTransition)

      WhyPager(beat: room.whyBeat, count: Self.beats.count) { room.setBeat($0) }
        .padding(.top, 16)

      if room.whyBeat == 2 {
        Text("\(Text("In real life:").bold()) swim underwater and look up at a slant, and the surface shines like a mirror. Glass cables carry internet light the same way.")
          .font(.system(.subheadline, design: .rounded))
          .foregroundStyle(LabColor.lumi)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 16)
          .transition(.opacity)
      }
    }
  }

  // MARK: 2.6 Challenge

  private var challenge: some View {
    VStack(alignment: .leading, spacing: 12) {
      title("Wake the moon lily")
      Text("Keep Lumi’s light inside the crystal vine.")
        .font(LabFont.body)
        .foregroundStyle(LabColor.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)
      angleControl(status: room.isAlmost ? "Almost. Tilt a little more." : nil)
        .padding(.top, 10)
    }
  }

  // MARK: 2.7 Solved

  private var solved: some View {
    VStack(alignment: .leading, spacing: 12) {
      title("The moon lily woke up!")
      Text("Internet cables carry light the same way.")
        .font(LabFont.body)
        .foregroundStyle(LabColor.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)
      FireflyRow(earned: room.state.fireflies, size: 40)
        .padding(.top, 8)
    }
  }

  // MARK: Readout and dial

  /// The live light angle, or the dial in its place when the hinge can’t drive the scene.
  /// While a sweep plays, the readout counts along with it.
  @ViewBuilder
  private func angleControl(status: String?) -> some View {
    if room.usesDial && room.demoTilt == nil {
      VStack(alignment: .leading, spacing: 8) {
        AngleDial(hinge: room.hinge, scale: .lightTilt)
        caption(status, fallback: "Drag to tilt")
      }
    } else {
      VStack(alignment: .leading, spacing: 0) {
        Text("\(Int(room.sceneTilt.rounded()))°")
          .font(.system(size: readoutSize, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(LabColor.primaryInk)
          .contentTransition(.numericText(value: room.sceneTilt))
        caption(status, fallback: "light angle")
          .padding(.leading, 4)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Light angle")
      .accessibilityValue("\(Int(room.sceneTilt.rounded())) degrees" + (status.map { ". \($0)" } ?? ""))
      .accessibilityAddTraits(.updatesFrequently)
    }
  }

  private func caption(_ status: String?, fallback: String) -> some View {
    Text(status ?? fallback)
      .font(status == nil ? LabFont.caption : .system(.subheadline, design: .rounded, weight: .medium))
      .foregroundStyle(status == nil ? LabColor.tertiaryInk : LabColor.label)
      .contentTransition(.opacity)
      .animation(.easeInOut(duration: 0.2), value: status)
  }

  // MARK: Actions

  /// The forward step, 40 pt from the bottom. A primary button is either shown or not, never disabled.
  private var actions: some View {
    HStack(spacing: 12) {
      switch room.step {
      case .tryIt:
        if room.crossedCritical {
          PrimaryLabButton(title: "What happened?", fillsWidth: false) { room.whatHappened() }
            .transition(rise)
        } else {
          QuietLabButton(title: room.isSweeping ? "Stop" : "Show me", systemImage: room.isSweeping ? "stop.fill" : nil) {
            room.showMe()
          }
          .padding(.leading, -8)
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
      case .solved:
        if celebrationDone {
          PrimaryLabButton(title: "Next: The Marble Ramp", fillsWidth: false) { room.finishRoom() }
            .transition(rise)
        }
      default:
        EmptyView()
      }
    }
    .frame(minHeight: 56)
    .animation(reduceMotion ? LabMotion.reduced : LabMotion.step, value: room.crossedCritical)
    .animation(reduceMotion ? LabMotion.reduced : LabMotion.step, value: room.checkOutcome)
    .animation(reduceMotion ? LabMotion.reduced : LabMotion.step, value: celebrationDone)
  }

  private var rise: AnyTransition {
    reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12))
  }

  private func title(_ text: String) -> some View {
    Text(text)
      .font(LabFont.title)
      .foregroundStyle(LabColor.primaryInk)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader)
  }
}
