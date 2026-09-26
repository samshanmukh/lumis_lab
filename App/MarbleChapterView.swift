import SwiftUI

/// The Marble Ramp chapter in Lumi’s Lab: its door, the hinge experiment, a prediction with two
/// ramps, and what it means. The garden scene sits on one side of the fold, and the words and
/// controls on the other.
struct MarbleChapterView: View {
  var onExitToMap: (() -> Void)?
  var onCompleted: (() -> Void)?
  @State private var stage: ChapterStage = .door
  @State private var ramp = MarbleChapterModel()
  @State private var quiz = MarbleQuizModel()
  @State private var showObjective = true
  @ScaledMetric(relativeTo: .largeTitle) private var angleSize: CGFloat = 44

  var body: some View {
    Group {
      if #available(iOS 27.1, *) {
        Group {
          if stage == .door {
            ChapterDoorView(onMap: onExitToMap) {
              withAnimation(.smooth) { stage = .experiment }
            }
          } else {
            ArrangementView {
              upperPane
            } secondary: {
              lowerPane
            }
            .arrangementViewStyle(.split)
          }
        }
        .onHingeChange { _, newContext in
          guard let hinge = newContext.hinge else {
            ramp.updateHinge(rawOpeningAngle: nil)
            return
          }

          switch hinge.status {
          case .partiallyOpen:
            ramp.updateHinge(rawOpeningAngle: hinge.angle.degrees)
          case .fullyOpen:
            ramp.updateHinge(rawOpeningAngle: 180)
          case .closed:
            ramp.updateHinge(rawOpeningAngle: 0)
          default:
            ramp.updateHinge(rawOpeningAngle: nil)
          }
        }
      } else {
        Group {
          if stage == .door {
            ChapterDoorView(onMap: onExitToMap) {
              withAnimation(.smooth) { stage = .experiment }
            }
          } else {
            VStack(spacing: 0) {
              upperPane.frame(maxWidth: .infinity, maxHeight: .infinity)
              lowerPane.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
          }
        }
      }
    }
    .background(LabColor.backgroundBottom.ignoresSafeArea())
    .preferredColorScheme(.dark)
    .statusBarHidden()
    .sensoryFeedback(.success, trigger: ramp.fireflyAwake)
    .task(id: stage) {
      guard stage == .experiment else { return }
      try? await Task.sleep(for: .seconds(4.5))
      guard !Task.isCancelled else { return }
      withAnimation(.smooth) { showObjective = false }
    }
    .task(id: ramp.isRolling) {
      guard ramp.isRolling else { return }
      var lastTick = Date.now
      while ramp.isRolling && !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(16))
        guard !Task.isCancelled else { return }
        let now = Date.now
        ramp.advance(by: now.timeIntervalSince(lastTick))
        lastTick = now
      }
    }
    .task(id: quiz.selected) {
      guard let delay = quiz.completionDelay else { return }
      try? await Task.sleep(for: .seconds(max(0, delay)))
      guard !Task.isCancelled else { return }
      withAnimation(.smooth) { quiz.finished = true }
    }
  }

  // MARK: The scene half

  @ViewBuilder
  private var upperPane: some View {
    switch stage {
    case .door:
      EmptyView()
    case .experiment:
      // The garden runs to the screen’s edges; the readout stays in the safe area.
      ZStack(alignment: .topTrailing) {
        RampScene(model: ramp)
          .ignoresSafeArea()
        hingeReadout
          .padding(18)
      }
    case .quiz:
      QuizScene(model: quiz) { choice in
        withAnimation(.snappy) { quiz.select(choice) }
      }
    case .next:
      ZStack {
        LabBackdrop()
        VStack(spacing: 18) {
          LumiView(mood: .happy, radius: 46)
            .overlay(alignment: .topTrailing) {
              FireflyView(lit: true, size: 34)
                .offset(x: 22, y: -8)
            }
          FireflyRow(earned: Set(Firefly.allCases), size: 26)
        }
      }
    }
  }

  private var hingeReadout: some View {
    VStack(alignment: .trailing, spacing: 2) {
      Text(ramp.hingeDegrees.map { "\(Int($0.rounded()))°" } ?? "—")
        .font(LabFont.readout(size: angleSize))
        .monospacedDigit()
        .foregroundStyle(LabColor.primaryInk)
        .contentTransition(.numericText())
      Text("hinge angle")
        .font(LabFont.caption)
        .foregroundStyle(LabColor.tertiaryInk)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Duo hinge angle")
    .accessibilityValue(ramp.hingeDegrees.map { "\(Int($0.rounded())) degrees" } ?? "Unavailable")
    .accessibilityHint("Move the Duo hinge to change this angle")
  }

  // MARK: The words half

  private var lowerPane: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 20) {
        if let onExitToMap {
          MapCapsule(action: onExitToMap)
        }
        ProgressDots(current: stage.progress, count: ChapterStage.steps)
        Spacer(minLength: 0)
      }
      .padding(.bottom, 10)

      switch stage {
      case .door: EmptyView()
      case .experiment: experimentControls
      case .quiz: quizControls
      case .next: nextInstructions
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 16)
    .padding(.bottom, 22)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(LabBackdrop(showsFireflies: false))
  }

  private var experimentControls: some View {
    VStack(alignment: .leading, spacing: 8) {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          title(ramp.fireflyAwake ? "The firefly is awake" : "Wake the firefly")

          if showObjective && !ramp.fireflyAwake {
            Text("Adjust the Duo’s hinge to change the ramp angle. Try to make the ball reach the firefly.")
              .font(LabFont.body)
              .foregroundStyle(LabColor.secondaryInk)
              .fixedSize(horizontal: false, vertical: true)
              .transition(.opacity)
          } else {
            experimentMessage
          }

          VStack(spacing: 10) {
            LabControlSlider(
              title: "Friction", value: $ramp.friction, range: 0...1,
              minimumLabel: "None", maximumLabel: "Lots",
              valueLabel: "\(Int((ramp.friction * 100).rounded()))%"
            )
            LabControlSlider(
              title: "Gravity", value: $ramp.gravity, range: 0.35...1.65,
              minimumLabel: "Tiny", maximumLabel: "Lots",
              valueLabel: "\(ramp.gravity.formatted(.number.precision(.fractionLength(1))))×"
            )
            LabControlSlider(
              title: "Mass", value: $ramp.mass, range: 5...100,
              minimumLabel: "5 kg", maximumLabel: "100 kg",
              valueLabel: "\(Int(ramp.mass.rounded())) kg"
            )
          }
          .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .scrollIndicators(.hidden)
      .scrollBounceBehavior(.basedOnSize)

      if ramp.fireflyAwake {
        PrimaryLabButton(title: "What happened?", fillsWidth: false) {
          withAnimation(.smooth) { stage = .quiz }
        }
      } else {
        PrimaryLabButton(title: "Roll", fillsWidth: false) {
          ramp.startTrial()
        }
        .disabled(!ramp.canRoll)
        .opacity(ramp.canRoll ? 1 : 0.5)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  /// How the last roll went, in the lab’s kind colours: lavender to try again, mint when it worked.
  @ViewBuilder
  private var experimentMessage: some View {
    if ramp.fireflyAwake {
      feedback("Your marble reached the firefly.", systemImage: "checkmark", ink: LabColor.correct)
    } else if ramp.isRolling {
      message("Watch where the marble stops.")
    } else if ramp.hingeDegrees == nil {
      message("Open on iPhone Duo and move its hinge to begin.")
    } else {
      switch ramp.lastOutcome {
      case .short: feedback("It stopped short. Change the hinge and try again.", systemImage: "arrow.counterclockwise", ink: LabColor.retry)
      case .long: feedback("It rolled past. Change the hinge and try again.", systemImage: "arrow.counterclockwise", ink: LabColor.retry)
      case .target: feedback("Your marble reached the firefly.", systemImage: "checkmark", ink: LabColor.correct)
      case nil: message("Adjust the hinge, then roll.")
      }
    }
  }

  private var quizControls: some View {
    VStack(alignment: .leading, spacing: 9) {
      if quiz.finished {
        title("The steep ball went farther")
        Text("A steeper ramp accelerates the ball faster. Starting higher gives it more energy.")
          .font(LabFont.body)
          .foregroundStyle(LabColor.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
        Text("PE = mgh")
          .font(.system(.title2, design: .rounded, weight: .semibold))
          .foregroundStyle(LabColor.lumi)
          .padding(.top, 3)
        Text("More height → more potential energy → more energy for motion.")
          .font(.system(.subheadline, design: .rounded))
          .foregroundStyle(LabColor.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 8)
        PrimaryLabButton(title: "Continue", fillsWidth: false) {
          onCompleted?()
          withAnimation(.smooth) { stage = .next }
        }
      } else {
        HStack(alignment: .top, spacing: 12) {
          LumiView(mood: quiz.isPlaying ? .wonder : .calm, radius: 15)
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
          title(quiz.isPlaying ? "Watch them roll" : "Which ball will travel farther?")
        }
        Text(quiz.isPlaying
             ? "Your pick rolls first. Then watch the other ball."
             : "Tap one of the two ramps above to make your prediction.")
          .font(LabFont.body)
          .foregroundStyle(LabColor.secondaryInk)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 12)
        Text(quiz.isPlaying ? "Compare where each ball stops." : "Choose a ramp to run the experiment.")
          .font(.system(.subheadline, design: .rounded, weight: .medium))
          .foregroundStyle(LabColor.label)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var nextInstructions: some View {
    VStack(alignment: .leading, spacing: 9) {
      title("Launch Angle")
      Text("The firefly is awake. The next experiment is ready to explore.")
        .font(LabFont.body)
        .foregroundStyle(LabColor.secondaryInk)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 12)
      PrimaryLabButton(title: "Replay Marble Ramp", fillsWidth: false) {
        ramp = MarbleChapterModel()
        quiz = MarbleQuizModel()
        showObjective = true
        withAnimation(.smooth) { stage = .door }
      }
      if let onExitToMap {
        QuietLabButton(title: "Back to map", action: onExitToMap)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func title(_ text: String) -> some View {
    Text(text)
      .font(LabFont.title)
      .foregroundStyle(LabColor.primaryInk)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader)
  }

  private func message(_ text: String) -> some View {
    Text(text)
      .font(LabFont.body)
      .foregroundStyle(LabColor.secondaryInk)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func feedback(_ text: String, systemImage: String, ink: Color) -> some View {
    Label(text, systemImage: systemImage)
      .font(.system(.body, design: .rounded, weight: .medium))
      .foregroundStyle(ink)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityElement(children: .combine)
  }
}

private enum ChapterStage: Hashable {
  case door
  case experiment
  case quiz
  case next

  static let steps = 3

  /// The dot lit in the progress row: the door comes before the first.
  var progress: Int {
    switch self {
    case .door: 0
    case .experiment: 1
    case .quiz: 2
    case .next: 3
    }
  }
}
