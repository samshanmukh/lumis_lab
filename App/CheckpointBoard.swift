import SwiftUI

/// The frosted-glass question board on a checkpoint. A tap is judged at once;
/// then the feedback fades in and the two buttons rise in.
struct CheckpointBoard: View {
  var room: MirrorRoomModel
  var seeIt: () -> Void

  var body: some View {
    let isFirst = room.step == .checkpoint1
    let outcome = room.checkpoint.outcome

    GeometryReader { geometry in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text(isFirst ? "At 90°, how many Lumis?" : "For more Lumis, move the mirrors…")
            .font(LabFont.title)
            .foregroundStyle(LabColor.primaryInk)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)

          if isFirst {
            Text("Count the real Lumi too.")
              .font(LabFont.body)
              .foregroundStyle(LabColor.secondaryInk)
              .padding(.top, 8)
          }

          choices(isFirst: isFirst)
            .padding(.top, isFirst ? 28 : 24)

          ZStack(alignment: .topLeading) {
            if let feedback = room.checkpointFeedback {
              Text(feedback)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(LabColor.primaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 22)
                .transition(.opacity)
            } else {
              QuietLabButton(title: "I’m not sure") { room.answer(.notSure) }
                .padding(.leading, -8)
                .padding(.top, 14)
                .transition(.opacity)
            }
          }

          Spacer(minLength: 32)

          if let outcome {
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
    .animation(LabMotion.step, value: outcome == nil)
  }

  @ViewBuilder
  private func choices(isFirst: Bool) -> some View {
    let picked = room.checkpoint.picked
    let outcome = room.checkpoint.outcome
    let locked = outcome != nil
    Group {
      if isFirst {
        HStack(spacing: 12) {
          ForEach([2, 3, 4, 6], id: \.self) { value in
            ChoiceChip(
              title: "\(value)",
              outline: .circle(64),
              mark: mark(for: .number(value), picked: picked, outcome: outcome),
              isLocked: locked
            ) {
              room.answer(.number(value))
            }
          }
        }
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 12) { secondChoices(picked: picked, outcome: outcome, locked: locked) }
          VStack(alignment: .leading, spacing: 12) { secondChoices(picked: picked, outcome: outcome, locked: locked) }
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(isFirst ? "At 90°, how many Lumis? Count the real Lumi too." : "For more Lumis, move the mirrors…")
  }

  @ViewBuilder
  private func secondChoices(picked: CheckpointChoice?, outcome: CheckpointOutcome?, locked: Bool) -> some View {
    ChoiceChip(title: "Closer together", outline: .capsule, mark: mark(for: .closer, picked: picked, outcome: outcome), isLocked: locked) {
      room.answer(.closer)
    }
    ChoiceChip(title: "Further apart", outline: .capsule, mark: mark(for: .further, picked: picked, outcome: outcome), isLocked: locked) {
      room.answer(.further)
    }
  }

  private func mark(for choice: CheckpointChoice, picked: CheckpointChoice?, outcome: CheckpointOutcome?) -> ChoiceChip.Mark {
    guard choice == picked else { return .rest }
    switch outcome {
    case .right: return .right
    case .wrong: return .wrong
    default: return .rest
    }
  }

  @ViewBuilder
  private func actions(for outcome: CheckpointOutcome) -> some View {
    let isFirst = room.step == .checkpoint1
    HStack(spacing: 12) {
      if outcome == .right {
        PrimaryLabButton(title: isFirst ? "Next" : "Next: The Glass Pond", fillsWidth: false) {
          room.checkpointForward()
        }
        QuietLabButton(title: "See it anyway", action: seeIt)
      } else {
        PrimaryLabButton(title: "See it", fillsWidth: false, action: seeIt)
        QuietLabButton(title: "Skip") { room.checkpointForward() }
      }
    }
  }
}
