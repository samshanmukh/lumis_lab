import SwiftUI

/// What a room earned: guess made, answer found, challenge solved.
struct FireflyRow: View {
  var earned: Set<Firefly>
  var size: CGFloat = 28
  /// How many slots are lit so far, for lighting them one by one.
  var lightCount = 3

  var body: some View {
    HStack(spacing: size * 0.3) {
      ForEach(Array(Firefly.allCases.enumerated()), id: \.element) { index, firefly in
        let lit = earned.contains(firefly) && index < lightCount
        FireflyView(lit: lit, size: size)
          .scaleEffect(lit ? 1 : 0.9)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(earned.count) of 3 fireflies")
  }
}
