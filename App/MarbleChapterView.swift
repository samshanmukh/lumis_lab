import SwiftUI

/// musa’s Marble Ramp chapter in the Lumi room layout: the moon garden on one half, the words and
/// controls on the other, split at the fold. Open like a laptop, the garden is on the upright half.
struct MarbleChapterView: View {
  var room: MarbleChapterRoom
  var map: () -> Void
  var leave: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @ScaledMetric(relativeTo: .largeTitle) private var readoutSize: CGFloat = 56
  @State private var celebrationDone = false

  var body: some View {
    Group {
      if room.stage == .roomEnd {
        roomEnd
          .transition(.opacity)
      } else {
        halves
          .transition(.opacity)
      }
    }
    .background { LabColor.background.ignoresSafeArea() }
    .toolbar {
      if showsToolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Map", systemImage: "chevron.left", action: map)
        }
        if room.hintContent != nil {
          ToolbarItem(placement: .primaryAction) {
            Button("Hint", systemImage: room.hint == nil ? "lightbulb" : "lightbulb.fill") {
              room.toggleHint()
            }
          }
        }
      }
    }
    .toolbar(showsToolbar ? .visible : .hidden, for: .navigationBar)
    .toolbarBackground(.hidden, for: .navigationBar)
    .sensoryFeedback(.success, trigger: room.successTick)
    .sensoryFeedback(.selection, trigger: room.selectionTick)
    .onChange(of: room.hinge.angle) { room.hingeChanged() }
    .task(id: room.ramp.fireflyAwake) { await celebrate() }
  }

  private static let scrollFade: CGFloat = 20

  private var showsToolbar: Bool { room.stage != .roomEnd }

  @ViewBuilder
  private var halves: some View {
    if #available(iOS 27.1, *) {
      ArrangementView {
        garden
      } secondary: {
        controls
      }
      .arrangementViewStyle(.split)
    } else {
      VStack(spacing: 0) {
        garden
        controls
      }
    }
  }

  // MARK: Garden

  /// The garden keeps clear of a vertical bar beside it, and its edges extend beneath it.
  private var garden: some View {
    MarbleSceneView(scene: room.scene)
      .ignoresSafeArea(edges: .top)
      .backgroundExtensionEffect()
      .overlay(alignment: .topLeading) {
        ProgressDots(current: room.stage.rawValue, count: MarbleChapterRoom.stageCount)
          .padding(.leading, 40)
          .padding(.top, 24)
      }
  }

  // MARK: Words and controls

  /// Only the words change between stages; the forward step sits at the foot.
  private var controls: some View {
    ZStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: 0) {
        ScrollView {
          content
            .id(room.stage)
            .transition(stepTransition)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Self.scrollFade)
        }
        .scrollBounceBehavior(.basedOnSize)
        // On a short screen the words fade out above the button, so it’s clear there’s more.
        .mask {
          VStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
              .frame(height: Self.scrollFade)
          }
        }

        actions
          .padding(.top, 12)
      }
      .padding(.leading, 40)
      .padding(.trailing, 24)
      .padding(.top, 32)
      .padding(.bottom, 16)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

      if let hint = room.hint, let content = room.hintContent {
        HintPanel(
          content: content,
          state: hint,
          gotIt: { room.closeHint() },
          anotherHint: { room.anotherHint() },
          showMe: {},
          stop: {}
        )
        .padding(12)
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
      }
    }
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
    switch room.stage {
    case .experiment: experiment
    case .quiz: quiz
    case .why: why
    case .roomEnd: EmptyView()
    }
  }

  // MARK: Wake the firefly

  private var experiment: some View {
    VStack(alignment: .leading, spacing: 0) {
      if room.ramp.fireflyAwake {
        title("The firefly woke up!")
        line("Your marble reached the firefly.")
      } else {
        title("Wake the firefly")
        line("Roll the marble all the way to the flower.")
        ViewThatFits(in: .horizontal) {
          HStack(alignment: .top, spacing: 32) {
            rampControl
            MarbleChapterSettings(room: room)
              .frame(width: 260)
          }
          VStack(alignment: .leading, spacing: 24) {
            rampControl
            MarbleChapterSettings(room: room)
          }
        }
        .padding(.top, 20)
        .transition(.opacity)
      }
    }
    .animation(reduceMotion ? LabMotion.reduced : LabMotion.step, value: room.ramp.fireflyAwake)
    .animation(.easeInOut(duration: 0.2), value: room.rollStatus)
  }

  /// The ramp angle is the number used: big, with the dial in its place when there’s no hinge.
  @ViewBuilder
  private var rampControl: some View {
    if room.usesDial {
      VStack(alignment: .leading, spacing: 8) {
        AngleDial(hinge: room.hinge, scale: .chapterRamp)
          .disabled(room.ramp.isRolling)
          .opacity(room.ramp.isRolling ? 0.45 : 1)
        caption("Drag to tilt")
        status
      }
    } else {
      VStack(alignment: .leading, spacing: 0) {
        Text("\(Int(room.ramp.rampDegrees.rounded()))°")
          .font(.system(size: readoutSize, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(LabColor.primaryInk)
          .contentTransition(.numericText(value: room.ramp.rampDegrees))
        caption("ramp angle")
          .padding(.leading, 4)
        status
          .padding(.leading, 4)
          .padding(.top, 6)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Ramp angle")
      .accessibilityValue("\(Int(room.ramp.rampDegrees.rounded())) degrees" + (room.rollStatus.map { ". \($0)" } ?? ""))
      .accessibilityAddTraits(.updatesFrequently)
    }
  }

  @ViewBuilder
  private var status: some View {
    if let status = room.rollStatus {
      Text(status)
        .font(.system(.subheadline, design: .rounded, weight: .medium))
        .foregroundStyle(LabColor.label)
        .fixedSize(horizontal: false, vertical: true)
        .transition(.opacity)
    }
  }

  // MARK: Predict

  private var quiz: some View {
    VStack(alignment: .leading, spacing: 0) {
      title("Which marble will roll farther?")

      ChipFlow(spacing: 12) {
        ForEach(QuizRamp.allCases) { choice in
          ChoiceChip(
            title: choice.title,
            outline: .capsule,
            mark: mark(for: choice),
            isLocked: room.quiz.selected != nil
          ) {
            room.pick(choice)
          }
        }
      }
      .padding(.top, 22)
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Which marble will roll farther?")

      Group {
        if let feedback = room.quizFeedback {
          if room.quiz.pickedRight {
            Label(feedback, systemImage: "checkmark")
              .foregroundStyle(LabColor.correct)
          } else {
            Text(feedback)
              .foregroundStyle(LabColor.primaryInk)
          }
        } else if room.quiz.isPlaying {
          Text("Your pick rolls first.")
            .foregroundStyle(LabColor.label)
        }
      }
      .font(.system(.body, design: .rounded, weight: .medium))
      .fixedSize(horizontal: false, vertical: true)
      .padding(.top, 20)
      .transition(.opacity)
      .accessibilityElement(children: .combine)
    }
    .animation(.easeOut(duration: 0.2), value: room.quiz.finished)
  }

  /// The pick shows as chosen while the marbles roll, then as right or wrong beside the answer.
  private func mark(for choice: QuizRamp) -> ChoiceChip.Mark {
    guard let picked = room.quiz.selected else { return .rest }
    if !room.quiz.finished { return choice == picked ? .picked : .rest }
    if choice == picked { return room.quiz.pickedRight ? .right : .wrong }
    return choice == MarbleQuizModel.answer ? .revealed : .rest
  }

  // MARK: Why

  private var why: some View {
    VStack(alignment: .leading, spacing: 0) {
      title("The steep marble went farther")
      line("A steeper ramp accelerates the marble faster. Starting higher gives it more energy.")
      Text("PE = mgh")
        .font(.system(.title2, design: .rounded, weight: .semibold))
        .foregroundStyle(LabColor.lumi)
        .padding(.top, 20)
        .accessibilityLabel("Potential energy equals mass times gravity times height.")
      Text("More height → more potential energy → more energy for motion.")
        .font(.system(.subheadline, design: .rounded))
        .foregroundStyle(LabColor.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 8)
        .accessibilityLabel("More height means more potential energy, and more energy for motion.")
    }
  }

  // MARK: Actions

  /// The forward step, shown or not, never disabled.
  private var actions: some View {
    HStack(spacing: 12) {
      switch room.stage {
      case .experiment:
        if !room.ramp.fireflyAwake {
          PrimaryLabButton(title: "Roll", fillsWidth: false) { room.roll() }
        } else if celebrationDone {
          PrimaryLabButton(title: "What happened?", fillsWidth: false) { room.startQuiz() }
            .transition(rise)
        }
      case .quiz:
        if room.quiz.finished {
          PrimaryLabButton(title: "Why?", fillsWidth: false) { room.startWhy() }
            .transition(rise)
        }
      case .why:
        PrimaryLabButton(title: "Next: \(RoomID.launchAngle.title)", fillsWidth: false) { room.finish() }
      case .roomEnd:
        EmptyView()
      }
    }
    .frame(minHeight: 56)
    .animation(reduceMotion ? LabMotion.reduced : LabMotion.step, value: celebrationDone)
    .animation(reduceMotion ? LabMotion.reduced : LabMotion.step, value: room.quiz.finished)
  }

  // MARK: Room end

  private var roomEnd: some View {
    GeometryReader { safeArea in
      let insets = safeArea.safeAreaInsets
      GeometryReader { proxy in
        RoomEndView(
          finished: MarbleChapterRoom.room,
          app: room.app,
          split: FoldSplit(size: proxy.size, insets: insets, foldX: FoldSplit.foldX(in: proxy), gap: 40, tallFirstShare: 0.55),
          leave: leave
        )
      }
      .ignoresSafeArea()
    }
  }

  /// celebrate (1.6 s) while the flower opens, then the forward button rises in.
  private func celebrate() async {
    guard room.ramp.fireflyAwake else {
      celebrationDone = false
      return
    }
    try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 1600))
    guard !Task.isCancelled else { return }
    celebrationDone = true
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

  private func caption(_ text: String) -> some View {
    Text(text)
      .font(LabFont.caption)
      .foregroundStyle(LabColor.tertiaryInk)
  }
}

/// The chapter’s lab settings. Friction and gravity change how far the marble rolls; mass only
/// changes how big it looks.
private struct MarbleChapterSettings: View {
  @Bindable var room: MarbleChapterRoom

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      LabControlSlider(
        title: "Friction", value: $room.ramp.friction, range: 0...1,
        minimumLabel: "None", maximumLabel: "Lots",
        valueLabel: "\(Int((room.ramp.friction * 100).rounded()))%"
      )
      LabControlSlider(
        title: "Gravity", value: $room.ramp.gravity, range: 0.35...1.65,
        minimumLabel: "Tiny", maximumLabel: "Lots",
        valueLabel: "\(room.ramp.gravity.formatted(.number.precision(.fractionLength(1))))×"
      )
      LabControlSlider(
        title: "Mass", value: $room.ramp.mass, range: 5...100,
        minimumLabel: "5 kg", maximumLabel: "100 kg",
        valueLabel: "\(Int(room.ramp.mass.rounded())) kg"
      )
    }
  }
}
