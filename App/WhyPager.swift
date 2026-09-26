import SwiftUI

/// Three beats: the current one is a lemon pill. One adjustable accessibility element.
struct WhyPager: View {
  var beat: Int
  var count: Int
  var select: (Int) -> Void

  var body: some View {
    HStack(spacing: 6) {
      ForEach(0..<count, id: \.self) { index in
        Capsule()
          .fill(index == beat ? LabColor.label : .white.opacity(0.3))
          .frame(width: index == beat ? 16 : 5, height: 5)
      }
    }
    .frame(minHeight: 20)
    .contentShape(Rectangle())
    .accessibilityElement()
    .accessibilityLabel("Why")
    .accessibilityValue("\(beat + 1) of \(count)")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: select(beat + 1)
      case .decrement: select(beat - 1)
      @unknown default: break
      }
    }
  }
}
