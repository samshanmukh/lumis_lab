import SwiftUI

/// What the dial shows and sets. It always drives the hinge model, so every rule that reads
/// the hinge works the same with the dial.
struct DialScale {
  var name: String
  var range: ClosedRange<Double>
  var detents: [Double]
  /// The dial’s value for a hinge angle, and the hinge angle for a dial value.
  var value: (Double) -> Double
  var hingeAngle: (Double) -> Double

  /// The Mirror Room: the mirror angle is the hinge angle, 40–180°, with detents at the neat angles.
  static let mirror = DialScale(
    name: "Mirror angle",
    range: 40...180,
    detents: [45, 60, 72, 90, 120, 180],
    value: { min(180, max(40, $0)) },
    hingeAngle: { $0 }
  )

  /// The Glass Pond: the light’s tilt, 0–60°.
  static let lightTilt = DialScale(
    name: "Light angle",
    range: GlassOptics.tiltRange,
    detents: [],
    value: GlassOptics.tilt(forHinge:),
    hingeAngle: GlassOptics.hinge(forTilt:)
  )

  /// The Marble Ramp: the upright screen’s tilt (180° − hinge), 15–50°. Dragging right makes the
  /// ramp steeper.
  static let rampTilt = DialScale(
    name: "Ramp angle",
    range: HingeModel.rampRange,
    detents: [15, 20, 30, 40, 45, 50],
    value: { min(HingeModel.rampRange.upperBound, max(HingeModel.rampRange.lowerBound, 180 - $0)) },
    hingeAngle: { 180 - $0 }
  )

  /// The Marble Ramp chapter: its ramp follows the fold (54° × tanh(fold ÷ 95°)), 10–45°. No
  /// detents, so any angle in between can wake the firefly.
  static let chapterRamp = DialScale(
    name: "Ramp angle",
    range: 10...45,
    detents: [],
    value: MarbleChapterModel.rampDegrees(forOpeningAngle:),
    hingeAngle: MarbleChapterModel.openingAngle(forRamp:)
  )
}

struct AngleDial: View {
  @Bindable var hinge: HingeModel
  var scale = DialScale.mirror
  @State private var dragging = false
  @State private var dragStart: Double?
  @State private var hapticTick = 0
  @State private var repeatTask: Task<Void, Never>?

  private var current: Double { scale.value(hinge.angle) }

  var body: some View {
    HStack(spacing: 8) {
      stepButton("Decrease angle", systemImage: "chevron.left", delta: -1)

      Text("\(Int(current.rounded()))°")
        .font(LabFont.readout(size: 28))
        .monospacedDigit()
        .foregroundStyle(dragging ? LabColor.label : LabColor.primaryInk)
        .frame(minWidth: 92, minHeight: 52)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { gesture in
              if dragStart == nil { dragStart = current }
              dragging = true
              updateAngle((dragStart ?? current) + gesture.translation.width / 4)
            }
            .onEnded { _ in
              dragging = false
              dragStart = nil
              if let nearest = scale.detents.min(by: { abs($0 - current) < abs($1 - current) }),
                 abs(nearest - current) <= 3 {
                updateAngle(nearest)
              }
            }
        )
        .accessibilityElement()
        .accessibilityLabel(scale.name)
        .accessibilityValue("\(Int(current.rounded())) degrees")
        .accessibilityHint("Swipe up or down to change by one degree")
        .accessibilityAdjustableAction { direction in
          switch direction {
          case .increment: updateAngle(current + 1)
          case .decrement: updateAngle(current - 1)
          @unknown default: break
          }
        }

      stepButton("Increase angle", systemImage: "chevron.right", delta: 1)
    }
    .padding(.horizontal, 8)
    .background(.white.opacity(0.08), in: Capsule())
    .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
    .sensoryFeedback(.selection, trigger: hapticTick)
    .onDisappear { repeatTask?.cancel() }
  }

  private func stepButton(_ title: String, systemImage: String, delta: Double) -> some View {
    Button(title, systemImage: systemImage) { updateAngle(current + delta) }
      .labelStyle(.iconOnly)
      .font(.headline)
      .foregroundStyle(LabColor.primaryInk)
      .frame(width: 48, height: 52)
      .contentShape(Rectangle())
      .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
        if pressing {
          repeatTask?.cancel()
          repeatTask = Task { @MainActor in
            while !Task.isCancelled {
              updateAngle(current + delta)
              try? await Task.sleep(for: .milliseconds(95))
            }
          }
        } else {
          repeatTask?.cancel()
          repeatTask = nil
        }
      }, perform: {})
  }

  private func updateAngle(_ value: Double) {
    let before = Int(current) / 5
    let clamped = min(scale.range.upperBound, max(scale.range.lowerBound, value))
    hinge.setDialAngle(scale.hingeAngle(clamped))
    if Int(current) / 5 != before { hapticTick += 1 }
  }
}
