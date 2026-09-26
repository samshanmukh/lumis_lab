import SwiftUI

/// A room whose checkpoints the board asks. Each room supplies its question and routes.
@MainActor
protocol CheckpointRoom: AnyObject {
  var step: RoomStep { get }
  var checkpoint: CheckpointState { get }
  var checkpointQuestion: CheckpointQuestion { get }
  var checkpointFeedback: String? { get }
  /// The primary after a right answer: “Next”, or the next room on the last checkpoint.
  var checkpointForwardTitle: String { get }
  func answer(_ choice: CheckpointChoice)
  func checkpointForward()
}

struct CheckpointQuestion {
  var title: String
  var detail: String?
  var options: [CheckpointOption]
}

struct CheckpointOption {
  var choice: CheckpointChoice
  var title: String
  var outline: ChoiceChip.Outline
}

/// The frosted-glass question board on a checkpoint. A tap is judged at once;
/// then the feedback fades in and the two buttons rise in.
struct CheckpointBoard: View {
  var room: any CheckpointRoom
  var seeIt: () -> Void

  var body: some View {
    let question = room.checkpointQuestion
    let outcome = room.checkpoint.outcome

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
              .fixedSize(horizontal: false, vertical: true)
              .padding(.top, 8)
          }

          choices(question)
            .padding(.top, 24)

          ZStack(alignment: .topLeading) {
            if let feedback = room.checkpointFeedback {
              Text(feedback)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(LabColor.primaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)
                .transition(.opacity)
            } else {
              QuietLabButton(title: "I’m not sure") { room.answer(.notSure) }
                .padding(.leading, -8)
                .padding(.top, 14)
                .transition(.opacity)
            }
          }

          Spacer(minLength: 16)

          if let outcome {
            actions(for: outcome)
              .transition(.opacity.combined(with: .offset(y: 12)))
          }
        }
        .padding(24)
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
  private func choices(_ question: CheckpointQuestion) -> some View {
    let allCircles = question.options.allSatisfy {
      if case .circle = $0.outline { return true }
      return false
    }
    Group {
      if allCircles {
        HStack(spacing: 12) { chips(question.options) }
      } else {
        ChipFlow(spacing: 12) { chips(question.options) }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel([question.title, question.detail].compactMap { $0 }.joined(separator: " "))
  }

  private func chips(_ options: [CheckpointOption]) -> some View {
    let picked = room.checkpoint.picked
    let outcome = room.checkpoint.outcome
    return ForEach(options, id: \.choice) { option in
      ChoiceChip(
        title: option.title,
        outline: option.outline,
        mark: mark(for: option.choice, picked: picked, outcome: outcome),
        isLocked: outcome != nil
      ) {
        room.answer(option.choice)
      }
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
    HStack(spacing: 12) {
      if outcome == .right {
        PrimaryLabButton(title: room.checkpointForwardTitle, fillsWidth: false) {
          room.checkpointForward()
        }
        QuietLabButton(title: "Replay", action: seeIt)
      } else {
        PrimaryLabButton(title: "See it", fillsWidth: false, action: seeIt)
        QuietLabButton(title: "Skip") { room.checkpointForward() }
      }
    }
  }
}

/// Chips in rows: as many as fit on a line, the rest wrap below, so answers stay readable at
/// any width and text size.
struct ChipFlow: Layout {
  var spacing: CGFloat = 12

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = arrange(subviews, width: proposal.width ?? .infinity)
    let width = rows.map { $0.width }.max() ?? 0
    let height = rows.map { $0.height }.reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
    return CGSize(width: width, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for row in arrange(subviews, width: bounds.width) {
      var x = bounds.minX
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
        x += size.width + spacing
      }
      y += row.height + spacing
    }
  }

  private struct Row {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
    var rows: [Row] = []
    var current = Row()
    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(.unspecified)
      let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
      if needed > width, !current.indices.isEmpty {
        rows.append(current)
        current = Row()
      }
      current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
      current.height = max(current.height, size.height)
      current.indices.append(index)
    }
    if !current.indices.isEmpty { rows.append(current) }
    return rows
  }
}
