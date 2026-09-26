import SwiftUI

/// The touch fallback for the hinge: drag at 1° per 4 pt, or tap ‹ › for 1° steps (long-press repeats).
/// The value turns lemon while dragging and snaps to the room’s neat angles.
struct AngleDial: View {
  var range: ClosedRange<Double>
  var snaps: [Double]
  var label: String
  /// Reads the live value, so long-press repeats and haptics never use a stale one.
  var read: () -> Double
  var write: (Double) -> Void

  @State private var dragging = false
  @State private var dragStart: Double?
  @State private var hapticTick = 0
  @State private var repeatTask: Task<Void, Never>?

  var body: some View {
    let value = read()
    HStack(spacing: 8) {
      stepButton("Decrease angle", systemImage: "chevron.left", delta: -1)

      Text("\(Int(value.rounded()))°")
        .font(LabFont.readout(size: 28))
        .monospacedDigit()
        .foregroundStyle(dragging ? LabColor.label : LabColor.primaryInk)
        .frame(minWidth: 92, minHeight: 52)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { gesture in
              if dragStart == nil { dragStart = read() }
              dragging = true
              update((dragStart ?? read()) + gesture.translation.width / 4)
            }
            .onEnded { _ in
              dragging = false
              dragStart = nil
              let current = read()
              if let nearest = snaps.min(by: { abs($0 - current) < abs($1 - current) }), abs(nearest - current) <= 3 {
                update(nearest)
              }
            }
        )
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value.rounded())) degrees")
        .accessibilityHint("Swipe up or down to change by one degree")
        .accessibilityAdjustableAction { direction in
          switch direction {
          case .increment: update(read() + 1)
          case .decrement: update(read() - 1)
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
    Button(title, systemImage: systemImage) { update(read() + delta) }
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
              update(read() + delta)
              try? await Task.sleep(for: .milliseconds(95))
            }
          }
        } else {
          repeatTask?.cancel()
          repeatTask = nil
        }
      }, perform: {})
  }

  private func update(_ newValue: Double) {
    let before = Int(read()) / 5
    write(min(range.upperBound, max(range.lowerBound, newValue)))
    if Int(read()) / 5 != before { hapticTick += 1 }
  }
}

extension AngleDial {
  /// The mirrors’ angle, 40–180°.
  init(hinge: HingeModel) {
    self.init(
      range: 40...180,
      snaps: [45, 60, 72, 90, 120, 180],
      label: "Mirror angle",
      read: { hinge.mirrorAngle },
      write: { hinge.setDialAngle($0) }
    )
  }

  /// The Marble Ramp’s tilt, 15–50°. Dragging right makes the ramp steeper.
  init(rampFor hinge: HingeModel) {
    self.init(
      range: HingeModel.rampRange,
      snaps: [15, 20, 30, 40, 45, 50],
      label: "Ramp angle",
      read: { hinge.rampAngle },
      write: { hinge.setRampAngle($0) }
    )
  }
}
