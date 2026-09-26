import SwiftUI

struct MarbleChapterView: View {
  var onExitToMap: (() -> Void)?
  var onCompleted: (() -> Void)?
  @State private var stage: ChapterStage = .door
  @State private var ramp = MarbleChapterModel()
  @State private var quiz = MarbleQuizModel()
  @State private var showObjective = true
  @ScaledMetric(relativeTo: .largeTitle) private var angleSize = 42

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
    .background(Color(red: 0.11, green: 0.09, blue: 0.34).ignoresSafeArea())
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

  @ViewBuilder
  private var upperPane: some View {
    switch stage {
    case .door:
      EmptyView()
    case .experiment:
      RampScene(model: ramp)
      .overlay(alignment: .topTrailing) {
        VStack(alignment: .trailing, spacing: 3) {
          Text("MARBLE RAMP")
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .tracking(1.7)
            .foregroundStyle(.white.opacity(0.68))
          HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(ramp.hingeDegrees.map { "\(Int($0.rounded()))°" } ?? "—")
              .font(.system(size: angleSize, weight: .semibold, design: .rounded))
              .monospacedDigit()
              .contentTransition(.numericText())
            Text("hinge")
              .font(.system(.caption, design: .rounded))
              .foregroundStyle(.white.opacity(0.75))
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel("Duo hinge angle")
          .accessibilityValue(ramp.hingeDegrees.map { "\(Int($0.rounded())) degrees" } ?? "Unavailable")
          .accessibilityHint("Move the Duo hinge to change this angle")
        }
        .padding(18)
      }
    case .quiz:
      QuizScene(model: quiz) { choice in
        withAnimation(.snappy) { quiz.select(choice) }
      }
    case .next:
      ZStack {
        LinearGradient(
          colors: [Color(red: 0.24, green: 0.20, blue: 0.59), Color(red: 0.12, green: 0.10, blue: 0.36)],
          startPoint: .top,
          endPoint: .bottom
        )
        Image("Marble_a6448")
          .resizable()
          .scaledToFit()
          .frame(width: 110)
          .shadow(color: Color(red: 1, green: 0.75, blue: 0.43), radius: 30)
      }
    }
  }

  @ViewBuilder
  private var lowerPane: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("LUMI’S LAB  /  CHAPTER 3")
          .font(.system(.caption2, design: .rounded, weight: .bold))
          .tracking(1.7)
          .foregroundStyle(.white.opacity(0.58))
        Spacer()
        if onExitToMap != nil {
          Button("Map") { onExitToMap?() }
            .font(.system(.caption, design: .rounded, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))
            .frame(minHeight: 44)
        }
      }
      .padding(.bottom, 8)

      switch stage {
      case .door: EmptyView()
      case .experiment: experimentControls
      case .quiz: quizControls
      case .next: nextInstructions
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 20)
    .padding(.bottom, 22)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(
      LinearGradient(
        colors: [Color(red: 0.18, green: 0.15, blue: 0.49), Color(red: 0.12, green: 0.10, blue: 0.35)],
        startPoint: .top,
        endPoint: .bottom
      )
    )
  }

  private var experimentControls: some View {
    VStack(alignment: .leading, spacing: 8) {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Text(ramp.fireflyAwake ? "The firefly is awake" : "Wake the firefly")
            .font(.system(.title2, design: .rounded, weight: .bold))

          if showObjective && !ramp.fireflyAwake {
            Text("Adjust the Duo’s hinge to change the ramp angle. Try to make the ball reach the firefly.")
              .font(.system(.subheadline, design: .rounded))
              .foregroundStyle(.white.opacity(0.88))
              .transition(.opacity)
          } else {
            Text(experimentMessage)
              .font(.system(.subheadline, design: .rounded))
              .foregroundStyle(ramp.fireflyAwake ? Color(red: 1, green: 0.85, blue: 0.61) : .white.opacity(0.76))
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

      if ramp.fireflyAwake {
        chapterButton("What happened?", systemImage: "arrow.right") {
          withAnimation(.smooth) { stage = .quiz }
        }
      } else {
        chapterButton("Roll", systemImage: "circle.fill") {
          ramp.startTrial()
        }
        .disabled(!ramp.canRoll)
        .opacity(ramp.canRoll ? 1 : 0.5)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var experimentMessage: String {
    if ramp.fireflyAwake { return "Your marble reached the firefly." }
    if ramp.isRolling { return "Watch where the marble stops." }
    if ramp.hingeDegrees == nil { return "Open on iPhone Duo and move its hinge to begin." }
    switch ramp.lastOutcome {
    case .short: return "It stopped short. Change the hinge and try again."
    case .long: return "It rolled past. Change the hinge and try again."
    case .target: return "Your marble reached the firefly."
    case nil: return "Adjust the hinge, then roll."
    }
  }

  private var quizControls: some View {
    VStack(alignment: .leading, spacing: 9) {
      if quiz.finished {
        Text("The steep ball went farther")
          .font(.system(.title2, design: .rounded, weight: .bold))
        Text("A steeper ramp accelerates the ball faster. Starting higher gives it more energy.")
          .font(.system(.subheadline, design: .rounded))
          .foregroundStyle(.white.opacity(0.86))
        Text("PE = mgh")
          .font(.system(.title3, design: .rounded, weight: .semibold))
          .foregroundStyle(Color(red: 1, green: 0.86, blue: 0.61))
          .padding(.top, 3)
        Text("More height → more potential energy → more energy for motion.")
          .font(.system(.subheadline, design: .rounded))
          .foregroundStyle(.white.opacity(0.76))
        Spacer(minLength: 8)
        chapterButton("Continue", systemImage: "arrow.right") {
          onCompleted?()
          withAnimation(.smooth) { stage = .next }
        }
      } else {
        Text(quiz.isPlaying ? "Watch them roll" : "Which ball will travel farther?")
          .font(.system(.title2, design: .rounded, weight: .bold))
        Text(quiz.isPlaying
             ? "Your pick rolls first. Then watch the other ball."
             : "Tap one of the two ramps above to make your prediction.")
          .font(.system(.body, design: .rounded))
          .foregroundStyle(.white.opacity(0.78))
        Spacer(minLength: 12)
        Text(quiz.isPlaying ? "Compare where each ball stops." : "Choose a ramp to run the experiment.")
          .font(.system(.subheadline, design: .rounded, weight: .medium))
          .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.61))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var nextInstructions: some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("Launch Angle")
        .font(.system(.title, design: .rounded, weight: .bold))
      Text("The firefly is awake. The next experiment is ready to explore.")
        .font(.system(.body, design: .rounded))
        .foregroundStyle(.white.opacity(0.76))
      Spacer(minLength: 12)
      chapterButton("Replay Marble Ramp", systemImage: "arrow.counterclockwise") {
        ramp = MarbleChapterModel()
        quiz = MarbleQuizModel()
        showObjective = true
        withAnimation(.smooth) { stage = .door }
      }
      if onExitToMap != nil {
        Button("Back to map") { onExitToMap?() }
          .font(.system(.subheadline, design: .rounded, weight: .medium))
          .foregroundStyle(.white.opacity(0.76))
          .frame(minHeight: 44)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func chapterButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.system(.body, design: .rounded, weight: .bold))
        .foregroundStyle(Color(red: 0.17, green: 0.12, blue: 0.43))
        .padding(.horizontal, 24)
        .frame(minHeight: 54)
        .background(
          LinearGradient(
            colors: [Color(red: 1, green: 0.96, blue: 0.87), Color(red: 0.79, green: 0.71, blue: 1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          in: Capsule()
        )
    }
    .buttonStyle(.plain)
  }
}

private enum ChapterStage: Hashable {
  case door
  case experiment
  case quiz
  case next
}
