import SwiftUI

struct PondControlPanel: View {
  var session: GlassPondSession
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        stageContent
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(24)
    }
    .scrollIndicators(.hidden)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(PondPalette.panelGradient)
    .animation(reduceMotion ? nil : .smooth, value: session.stage)
  }

  @ViewBuilder
  private var stageContent: some View {
    switch session.stage {
    case .entrance:
      entrance
    case .prediction:
      prediction
    case .experiment:
      experiment
    case .check:
      check
    case .explanation:
      explanation
    case .checkpointTwo:
      checkpointTwo
    case .challenge:
      challenge
    case .solved:
      solved
    }
  }

  private var entrance: some View {
    VStack(alignment: .leading, spacing: 16) {
      eyebrow("ROOM 2")
      Text("The Glass Pond")
        .font(.largeTitle.bold())
      Text("Lumi fell into a pond of magic glass. Can her light wake the moon lily?")
        .font(.body)
        .foregroundStyle(.white.opacity(0.85))
      Text("Open iPhone Duo like a laptop, or use the dial inside the room.")
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.72))
      primaryButton("Enter the room", action: session.enterRoom)
    }
  }

  private var prediction: some View {
    VStack(alignment: .leading, spacing: 16) {
      eyebrow("PREDICT")
      Text("If Lumi tilts more…")
        .font(.title2.bold())
      Text("What happens to her light at the surface?")
        .font(.body)
        .foregroundStyle(.white.opacity(0.82))
      PondAnswerChoices(selection: session.prediction) { answer in
        session.choosePrediction(answer)
      }
      if let prediction = session.prediction {
        Text(prediction == .stuck
          ? "Yes! Tilt far enough and the light can stay inside."
          : "Let’s try it and watch what the light does.")
          .font(.callout)
          .foregroundStyle(PondPalette.moon)
        primaryButton("See it", action: session.startExperiment)
      } else {
        Button("I’m not sure") { session.startExperiment() }
          .font(.callout.weight(.semibold))
          .foregroundStyle(.white)
          .frame(minHeight: 44)
      }
    }
  }

  private var experiment: some View {
    VStack(alignment: .leading, spacing: 15) {
      eyebrow("TRY IT")
      Text("Tilt the screen")
        .font(.title2.bold())
      angleReadout
      Text(session.snapshot.status)
        .font(.callout.weight(.medium))
        .foregroundStyle(session.snapshot.state == .trapped ? PondPalette.moon : .white.opacity(0.86))
        .accessibilityAddTraits(.updatesFrequently)
      angleDial
      HStack(spacing: 14) {
        Button("Show me", systemImage: "sparkles") { session.showMe() }
          .disabled(session.isShowingSweep)
        if session.whatHappenedAvailable {
          primaryButton("What happened?", action: session.askWhatHappened)
        }
      }
    }
  }

  private var check: some View {
    VStack(alignment: .leading, spacing: 16) {
      eyebrow("CHECK")
      Text("What happened to the light?")
        .font(.title2.bold())
      Text("Tilt again if you want another look.")
        .font(.callout)
        .foregroundStyle(.white.opacity(0.8))
      PondAnswerChoices(
        selection: session.answerRevealed ? .stuck : session.checkAnswer,
        correctAnswer: session.answerRevealed ? .stuck : nil
      ) { answer in
        session.chooseCheckAnswer(answer)
      }
      if let feedback = session.checkFeedback {
        Text(feedback)
          .font(.callout.weight(.medium))
          .foregroundStyle(PondPalette.moon)
          .accessibilityAddTraits(.updatesFrequently)
      }
      if session.answerRevealed {
        primaryButton("Why?", action: session.startExplanation)
      } else {
        angleDial
      }
    }
  }

  private var explanation: some View {
    VStack(alignment: .leading, spacing: 15) {
      eyebrow("WHY · \(session.explanationBeat + 1) OF 3")
      Text(explanationTitle)
        .font(.title2.bold())
      Text(explanationText)
        .font(.body)
        .foregroundStyle(.white.opacity(0.86))
      HStack(spacing: 5) {
        ForEach(0..<3) { index in
          Capsule()
            .fill(index == session.explanationBeat ? PondPalette.moon : .white.opacity(0.35))
            .frame(width: index == session.explanationBeat ? 16 : 5, height: 5)
        }
      }
      .accessibilityLabel("Explanation, page \(session.explanationBeat + 1) of 3")
      HStack {
        if session.explanationBeat > 0 {
          Button("Back") { session.previousExplanationBeat() }
        }
        primaryButton(session.explanationBeat == 2 ? "Try the challenge" : "Next") {
          session.nextExplanationBeat()
        }
      }
    }
  }

  private var explanationTitle: String {
    switch session.explanationBeat {
    case 0: "Light bends as it leaves glass"
    case 1: "More tilt, more bend"
    default: "Past 42°, the surface is a mirror"
    }
  }

  private var explanationText: String {
    switch session.explanationBeat {
    case 0:
      "Light travels slower in glass than in air. When it crosses out at a slant, it speeds up and swings away from straight up, like a wagon rolling from grass onto a sidewalk."
    case 1:
      "Tilt the light more and it bends more, until at about 42° it can only skim along the surface."
    default:
      "Tilt past that point and no light escapes. The surface reflects it all back inside the glass. This is called total internal reflection."
    }
  }

  private var checkpointTwo: some View {
    VStack(alignment: .leading, spacing: 16) {
      eyebrow("APPLY")
      Text("To keep the light inside…")
        .font(.title2.bold())
      Text("Which way should Lumi tilt?")
        .font(.body)
        .foregroundStyle(.white.opacity(0.85))
      ViewThatFits {
        HStack(spacing: 10) { vineChoices }
        VStack(spacing: 10) { vineChoices }
      }
      if let answer = session.checkpointTwoAnswer {
        Text(answer == .pastCritical
          ? "Right. Past 42°, the light stays in the glass."
          : "Let’s try it and see where the light escapes.")
          .font(.callout.weight(.medium))
          .foregroundStyle(PondPalette.moon)
        primaryButton("Try the challenge", action: session.beginChallenge)
      } else {
        Button("I’m not sure") { session.beginChallenge() }
          .font(.callout.weight(.semibold))
          .foregroundStyle(.white)
          .frame(minHeight: 44)
      }
    }
  }

  @ViewBuilder
  private var vineChoices: some View {
    ForEach(VineAnswer.allCases) { answer in
      PondChoiceChip(
        title: answer.title,
        isSelected: session.checkpointTwoAnswer == answer,
        isCorrect: session.checkpointTwoAnswer == answer && answer == .pastCritical
      ) {
        session.chooseCheckpointTwo(answer)
      }
    }
  }

  private var challenge: some View {
    VStack(alignment: .leading, spacing: 15) {
      eyebrow("CHALLENGE")
      Text("Wake the moon lily")
        .font(.title2.bold())
      Text("Keep Lumi’s light inside the crystal vine.")
        .font(.body)
        .foregroundStyle(.white.opacity(0.85))
      angleReadout
      Text(challengeStatus)
        .font(.callout.weight(.medium))
        .foregroundStyle(session.tilt >= 38 ? PondPalette.moon : .white.opacity(0.85))
        .accessibilityAddTraits(.updatesFrequently)
      angleDial
    }
  }

  private var challengeStatus: String {
    if session.tilt >= GlassOptics.criticalAngle { return "The light is reaching the lily…" }
    if session.tilt >= 38 { return "Almost. Tilt a little more." }
    return "Light escapes at the first bounce."
  }

  private var solved: some View {
    VStack(alignment: .leading, spacing: 17) {
      eyebrow("ROOM COMPLETE")
      Text("The moon lily woke up!")
        .font(.title2.bold())
      Text("Internet cables carry light the same way.")
        .font(.body)
        .foregroundStyle(.white.opacity(0.85))
      HStack(spacing: 12) {
        ForEach(0..<3) { index in
          Image(systemName: "sparkle")
            .foregroundStyle(index < session.earnedFireflies ? PondPalette.moon : .white.opacity(0.28))
            .frame(width: 26, height: 26)
        }
      }
      .accessibilityLabel("\(session.earnedFireflies) of 3 fireflies earned")
      primaryButton("Play again", action: session.reset)
      Text("The Marble Ramp is next in the full journey.")
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.7))
    }
  }

  private var angleReadout: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text("\(Int(session.tilt.rounded()))°")
        .font(.largeTitle.bold().monospacedDigit())
      Text("light angle")
        .font(.caption)
        .foregroundStyle(.white.opacity(0.7))
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Light angle")
    .accessibilityValue("\(Int(session.tilt.rounded())) degrees")
    .accessibilityAddTraits(.updatesFrequently)
  }

  private var angleDial: some View {
    VStack(alignment: .leading, spacing: 5) {
      Slider(value: angleBinding, in: 0...60) {
        Text("Light angle")
      } minimumValueLabel: {
        Text("0°")
      } maximumValueLabel: {
        Text("60°")
      }
      .tint(PondPalette.pond)
      .accessibilityValue("\(Int(session.tilt.rounded())) degrees")
      HStack {
        Text(session.inputMode == .hinge ? "Hinge is controlling the light" : "Move the dial to tilt the light")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.7))
        Spacer(minLength: 8)
        if session.hingeAvailable && session.inputMode == .dial {
          Button("Use hinge") { session.useHinge() }
            .font(.caption.weight(.semibold))
        }
      }
    }
  }

  private var angleBinding: Binding<Double> {
    Binding(
      get: { session.tilt },
      set: { session.setDialTilt($0) }
    )
  }

  private func eyebrow(_ title: String) -> some View {
    Text(title)
      .font(.caption.weight(.bold))
      .tracking(1.5)
      .foregroundStyle(PondPalette.pond)
  }

  private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button {
      action()
    } label: {
      Text(title)
        .font(.headline)
        .foregroundStyle(PondPalette.nightBottom)
        .frame(maxWidth: .infinity, minHeight: 48)
        .padding(.horizontal, 16)
        .background(PondPalette.lavender, in: Capsule())
    }
    .buttonStyle(.plain)
  }
}

private struct PondAnswerChoices: View {
  var selection: PondAnswer?
  var correctAnswer: PondAnswer? = nil
  var choose: (PondAnswer) -> Void

  var body: some View {
    ViewThatFits {
      HStack(spacing: 8) { chips }
      VStack(spacing: 8) { chips }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Answer choices")
  }

  @ViewBuilder
  private var chips: some View {
    ForEach(PondAnswer.allCases) { answer in
      PondChoiceChip(
        title: answer.title,
        isSelected: selection == answer,
        isCorrect: correctAnswer == answer
      ) {
        choose(answer)
      }
    }
  }
}

private struct PondChoiceChip: View {
  var title: String
  var isSelected: Bool
  var isCorrect: Bool
  var action: () -> Void

  var body: some View {
    Button {
      action()
    } label: {
      Text(title)
        .font(.subheadline.weight(.medium))
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, 10)
        .background(isCorrect ? PondPalette.pond.opacity(0.28) : .white.opacity(isSelected ? 0.22 : 0.12), in: Capsule())
        .overlay {
          Capsule()
            .strokeBorder(isCorrect ? PondPalette.pond : .white.opacity(isSelected ? 0.7 : 0.15), lineWidth: 1.5)
        }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
