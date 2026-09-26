import SwiftUI

/// 1.9, adapted for this build: the four rooms as a ladder with the path lit to the
/// Glass Pond, and “Coming soon” where its door will be. Leaves after 2.5 s or a tap.
struct RoomEndView: View {
  var fireflies: Set<Firefly>
  var split: FoldSplit
  var leave: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var litDots = 0
  @State private var ringShown = false
  @State private var didLeave = false

  private let travelledDots = 7

  var body: some View {
    ZStack(alignment: .topLeading) {
      LabBackdrop()
      if split.isSideBySide {
        ladder.place(in: split.first)
        nextRoom.place(in: split.second)
      } else {
        ladder.place(in: split.first.union(split.second))
      }
    }
    .contentShape(Rectangle())
    .onTapGesture { finish() }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("The Mirror Room done. Next: The Glass Pond, coming soon.")
    .accessibilityAddTraits(.isButton)
    .accessibilityHint("Goes back to the journey")
    .accessibilityAction { finish() }
    .task { await play() }
  }

  private var ladder: some View {
    VStack(alignment: .leading, spacing: 0) {
      stop(.launchAngle, size: 60, dimmed: true)
      dots(count: 4, lit: 0)
      stop(.marbleRamp, size: 60, dimmed: true)
      dots(count: 4, lit: 0)
      glassPondStop
      dots(count: travelledDots, lit: litDots)
      mirrorStop
    }
    .padding(.horizontal, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  private var mirrorStop: some View {
    HStack(spacing: 20) {
      RoomVignetteView(room: .mirror, size: 76)
        .shadow(color: LabColor.glow.opacity(0.5), radius: 14)
        .frame(width: 96)
      VStack(alignment: .leading, spacing: 8) {
        Text(RoomID.mirror.title)
          .font(LabFont.label)
          .foregroundStyle(LabColor.primaryInk)
        FireflyRow(earned: fireflies, size: 22)
      }
    }
  }

  private var glassPondStop: some View {
    HStack(spacing: 20) {
      RoomVignetteView(room: .glassPond, size: 96)
        .overlay {
          Circle()
            .strokeBorder(LabColor.retry.opacity(0.8), lineWidth: 2)
            .padding(-8)
            .opacity(ringShown ? 1 : 0)
        }
        .shadow(color: LabColor.retry.opacity(ringShown ? 0.5 : 0), radius: 18)
        .scaleEffect(ringShown ? 1 : 0.86)
        .frame(width: 96)
      VStack(alignment: .leading, spacing: 4) {
        Text(RoomID.glassPond.title)
          .font(.system(.title2, design: .rounded, weight: .bold))
          .foregroundStyle(LabColor.primaryInk)
        Text(split.isSideBySide ? "Next" : "Next · Coming soon")
          .font(LabFont.caption)
          .foregroundStyle(LabColor.secondaryInk)
      }
    }
  }

  private func stop(_ room: RoomID, size: CGFloat, dimmed: Bool) -> some View {
    HStack(spacing: 20) {
      RoomVignetteView(room: room, size: size)
        .frame(width: 96)
      Text(room.title)
        .font(LabFont.label)
        .foregroundStyle(LabColor.secondaryInk)
    }
    .opacity(dimmed ? 0.45 : 1)
  }

  /// Soft lights between stops, never a solid line. Lit ones are the way travelled.
  private func dots(count: Int, lit: Int) -> some View {
    VStack(spacing: 8) {
      ForEach(0..<count, id: \.self) { index in
        let isLit = count - index <= lit
        Circle()
          .fill(isLit ? LabColor.softLight : LabColor.retry.opacity(0.35))
          .frame(width: 5, height: 5)
          .shadow(color: isLit ? LabColor.softLight : .clear, radius: 4)
      }
    }
    .frame(width: 96)
    .padding(.vertical, 8)
    .accessibilityHidden(true)
  }

  private var nextRoom: some View {
    VStack(spacing: 18) {
      RoomVignetteView(room: .glassPond, size: 150)
        .overlay(Circle().strokeBorder(LabColor.retry.opacity(0.5), lineWidth: 2))
        .shadow(color: LabColor.retry.opacity(0.35), radius: 24)
      Text(RoomID.glassPond.title)
        .font(LabFont.title)
        .foregroundStyle(LabColor.primaryInk)
      Text("Coming soon")
        .font(LabFont.body)
        .foregroundStyle(LabColor.secondaryInk)
    }
    .opacity(ringShown ? 1 : 0)
    .offset(y: ringShown || reduceMotion ? 0 : 12)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func play() async {
    let start = ContinuousClock.now
    if reduceMotion {
      litDots = travelledDots
      withAnimation(LabMotion.reduced) { ringShown = true }
    } else {
      try? await Task.sleep(for: .milliseconds(250))
      for dot in 1...travelledDots {
        withAnimation(.easeOut(duration: 0.12)) { litDots = dot }
        try? await Task.sleep(for: .milliseconds(50))
      }
      withAnimation(.spring(duration: 0.4, bounce: 0.2)) { ringShown = true }
    }
    try? await Task.sleep(until: start + .milliseconds(2500), clock: .continuous)
    guard !Task.isCancelled else { return }
    finish()
  }

  private func finish() {
    guard !didLeave else { return }
    didLeave = true
    leave()
  }
}
