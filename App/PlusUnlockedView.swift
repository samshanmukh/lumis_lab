import SwiftUI

/// 7.5 · Tells the kid Plus is open. Launch Angle isn’t built yet, so this says it’s coming
/// rather than opening it, and its journey stop reads “Coming soon” until the room exists.
struct PlusUnlockedView: View {
  var room: RoomID
  var done: () -> Void

  @State private var celebrated = false

  var body: some View {
    LumiMessagePage(
      mood: .happy,
      title: "\(room.title) is unlocked!",
      line: "Lumi is still building it. Look for it on your journey soon.",
      lumiShare: 0.5,
      decoration: { UnlockFireflies() },
      actions: { PrimaryLabButton(title: "Back to the journey", fillsWidth: false, action: done) }
    )
    .sensoryFeedback(.success, trigger: celebrated)
    .onAppear { celebrated = true }
  }
}

/// celebrate: seven fireflies drift in and settle in an arc over Lumi, never over her.
/// With Reduce Motion they fade in where they settle.
private struct UnlockFireflies: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var settled = false

  private let count = 7

  var body: some View {
    GeometryReader { proxy in
      let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
      let spread = min(1, proxy.size.width / 480)
      ForEach(0..<count, id: \.self) { index in
        FireflyView(size: 34)
          .position(settled || reduceMotion ? arcPoint(index, center: center, spread: spread) : entryPoint(index, in: proxy.size))
          .opacity(settled ? 1 : 0)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .task { await settle() }
  }

  /// 60° either side of straight up, clear of Lumi’s glow.
  private func arcPoint(_ index: Int, center: CGPoint, spread: CGFloat) -> CGPoint {
    let angle = Angle.degrees(-60 + Double(index) * 120 / Double(count - 1)).radians
    return CGPoint(
      x: center.x + CGFloat(sin(angle)) * 190 * spread,
      y: center.y - CGFloat(cos(angle)) * 150 - 24
    )
  }

  private func entryPoint(_ index: Int, in size: CGSize) -> CGPoint {
    CGPoint(
      x: index.isMultiple(of: 2) ? -40 : size.width + 40,
      y: size.height * (0.1 + 0.12 * CGFloat(index))
    )
  }

  private func settle() async {
    if reduceMotion {
      withAnimation(LabMotion.reduced) { settled = true }
      return
    }
    try? await Task.sleep(for: .milliseconds(150))
    withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { settled = true }
  }
}
