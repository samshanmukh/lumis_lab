import SwiftUI

/// The frosted-glass question board on a checkpoint. A tap is judged at once;
/// then the feedback fades in and the two buttons rise in.
struct CheckpointBoard: View {
  var question: CheckpointQuestion
  var state: CheckpointState
  var feedback: String?
  var answer: (CheckpointChoice) -> Void
  var forward: () -> Void
  var seeIt: () -> Void

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text(question.title)
            .font(LabFont.title)
            .foregroundStyle(LabColor.primaryInk)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)

          if let detail = question.detail {
            Text(detail)
              .font(LabFont.body)
              .foregroundStyle(LabColor.secondaryInk)
              .padding(.top, 8)
          }

          choices
            .padding(.top, question.detail == nil ? 24 : 28)

          ZStack(alignment: .topLeading) {
            if let feedback {
              Text(feedback)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(LabColor.primaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)
                .transition(.opacity)
            } else {
              QuietLabButton(title: "I’m not sure") { answer(.notSure) }
                .padding(.leading, -8)
                .padding(.top, 14)
                .transition(.opacity)
            }
          }

          Spacer(minLength: 32)

          if let outcome = state.outcome {
            actions(for: outcome)
              .transition(.opacity.combined(with: .offset(y: 12)))
          }
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .topLeading)
      }
      .scrollBounceBehavior(.basedOnSize)
    }
    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.16), lineWidth: 1))
    .shadow(color: LabColor.shadow.opacity(0.35), radius: 15, y: 12)
    .animation(LabMotion.step, value: state.outcome == nil)
  }

  @ViewBuilder
  private var choices: some View {
    Group {
      switch question.style {
      case .numbers:
        HStack(spacing: 12) { chips }
      case .words:
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 12) { chips }
          VStack(alignment: .leading, spacing: 12) { chips }
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel([question.title, question.detail].compactMap { $0 }.joined(separator: " "))
  }

  private var chips: some View {
    ForEach(question.options) { option in
      ChoiceChip(
        title: option.title,
        outline: question.style == .numbers ? .circle(64) : .capsule,
        mark: mark(for: option.choice),
        isLocked: state.outcome != nil
      ) {
        answer(option.choice)
      }
    }
  }

  private func mark(for choice: CheckpointChoice) -> ChoiceChip.Mark {
    guard choice == state.picked else { return .rest }
    switch state.outcome {
    case .right: return .right
    case .wrong: return .wrong
    default: return .rest
    }
  }

  @ViewBuilder
  private func actions(for outcome: CheckpointOutcome) -> some View {
    HStack(spacing: 12) {
      if outcome == .right {
        PrimaryLabButton(title: question.forwardTitle, fillsWidth: false, action: forward)
        QuietLabButton(title: "Replay", action: seeIt)
      } else {
        PrimaryLabButton(title: "See it", fillsWidth: false, action: seeIt)
        QuietLabButton(title: "Skip", action: forward)
      }
    }
  }
}

/// A checkpoint’s question: its words, its choices and where Next goes.
struct CheckpointQuestion {
  enum Style {
    case numbers
    case words
  }

  var title: String
  var detail: String?
  var options: [CheckpointOption]
  var style: Style
  var forwardTitle: String
}

struct CheckpointOption: Identifiable {
  var choice: CheckpointChoice
  var title: String

  var id: String { choice.savedValue }
}
