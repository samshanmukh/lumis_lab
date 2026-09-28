import SwiftUI

/// An answer choice, judged the moment it’s tapped. Unchosen chips never fade.
struct ChoiceChip: View {
  enum Mark: Equatable {
    case rest
    /// Chosen, before the scene shows whether it was right.
    case picked
    case right
    case wrong
    case revealed
  }

  enum Outline {
    case circle(CGFloat)
    case capsule
  }

  var title: String
  var outline: Outline
  var mark: Mark
  var isLocked = false
  var action: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shakes = 0

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(font)
        .monospacedDigit()
        .foregroundStyle(LabColor.primaryInk)
        .padding(.horizontal, isCircle ? 0 : 23)
        .frame(width: diameter, height: diameter ?? 56)
        .background(fill, in: chipShape)
        .overlay(chipShape.strokeBorder(ring, lineWidth: mark == .rest ? 1 : 2))
        .shadow(color: mark == .right ? LabColor.correct.opacity(0.28) : .clear, radius: 16)
        .contentShape(chipShape)
    }
    .buttonStyle(ChipPressStyle())
    .disabled(isLocked)
    .labShake(trigger: shakes)
    .onChange(of: mark) { _, newMark in
      if newMark == .wrong, !reduceMotion { shakes += 1 }
    }
    .accessibilityAddTraits(mark == .rest ? [] : .isSelected)
    .accessibilityValue(accessibilityValue)
  }

  private var isCircle: Bool {
    if case .circle = outline { return true }
    return false
  }

  private var diameter: CGFloat? {
    if case .circle(let size) = outline { return size }
    return nil
  }

  private var chipShape: some InsettableShape {
    RoundedRectangle(cornerRadius: 32, style: .continuous)
  }

  private var font: Font {
    if isCircle {
      .system(.title2, design: .rounded, weight: mark == .rest ? .medium : .semibold)
    } else {
      .system(.body, design: .rounded, weight: .medium)
    }
  }

  private var fill: Color {
    switch mark {
    case .rest: .white.opacity(0.07)
    case .picked: .white.opacity(0.16)
    case .right: LabColor.correct.opacity(0.16)
    case .wrong: LabColor.retry.opacity(0.14)
    case .revealed: LabColor.correct.opacity(0.08)
    }
  }

  private var ring: Color {
    switch mark {
    case .rest: .white.opacity(0.12)
    case .picked: LabColor.primaryInk.opacity(0.85)
    case .right: LabColor.correct
    case .wrong: LabColor.retry
    case .revealed: LabColor.correct.opacity(0.6)
    }
  }

  private var accessibilityValue: String {
    switch mark {
    case .rest: ""
    case .picked: "Your pick"
    case .right: "Right"
    case .wrong: "Not quite"
    case .revealed: "The answer"
    }
  }
}

private struct ChipPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .brightness(configuration.isPressed ? 0.06 : 0)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
