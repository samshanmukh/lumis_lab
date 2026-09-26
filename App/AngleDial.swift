import SwiftUI

struct AngleDial: View {
  @Bindable var hinge: HingeModel
  @State private var dragging = false
  @State private var dragStart: Double?
  @State private var hapticTick = 0
  @State private var repeatTask: Task<Void, Never>?

  private let snapAngles: [Double] = [45, 60, 72, 90, 120, 180]

  var body: some View {
    HStack(spacing: 8) {
      stepButton("Decrease angle", systemImage: "chevron.left", delta: -1)

      Text("\(Int(hinge.mirrorAngle.rounded()))°")
        .font(LabFont.readout(size: 28))
        .monospacedDigit()
        .foregroundStyle(dragging ? LabColor.label : LabColor.primaryInk)
        .frame(minWidth: 92, minHeight: 52)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { gesture in
              if dragStart == nil { dragStart = hinge.mirrorAngle }
              dragging = true
              updateAngle((dragStart ?? hinge.mirrorAngle) + gesture.translation.width / 4)
            }
            .onEnded { _ in
              dragging = false
              dragStart = nil
              if let nearest = snapAngles.min(by: { abs($0 - hinge.mirrorAngle) < abs($1 - hinge.mirrorAngle) }),
                 abs(nearest - hinge.mirrorAngle) <= 3 {
                updateAngle(nearest)
              }
            }
        )
        .accessibilityElement()
        .accessibilityLabel("Mirror angle")
        .accessibilityValue("\(Int(hinge.mirrorAngle.rounded())) degrees")
        .accessibilityHint("Swipe up or down to change by one degree")
        .accessibilityAdjustableAction { direction in
          switch direction {
          case .increment: updateAngle(hinge.mirrorAngle + 1)
          case .decrement: updateAngle(hinge.mirrorAngle - 1)
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
    Button(title, systemImage: systemImage) { updateAngle(hinge.mirrorAngle + delta) }
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
              updateAngle(hinge.mirrorAngle + delta)
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
    let before = Int(hinge.mirrorAngle) / 5
    hinge.setDialAngle(value)
    if Int(hinge.mirrorAngle) / 5 != before { hapticTick += 1 }
  }
}
