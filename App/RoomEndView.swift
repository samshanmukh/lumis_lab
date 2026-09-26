import SwiftUI

/// X.9, adapted for this build: the four rooms as a ladder with the path lit from the finished
/// room to the next one, and “Coming soon” where an unbuilt room’s door will be.
/// Leaves after 2.5 s or a tap.
struct RoomEndView: View {
  var finished: RoomID
  var fireflies: [RoomID: Set<Firefly>]
  var solved: Set<RoomID>
  var split: FoldSplit
  var leave: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var litDots = 0
  @State private var ringShown = false
  @State private var didLeave = false

  private let travelledDots = 7

  private var next: RoomID? { finished.next }

  private var summary: String {
    guard let next else { return "\(finished.title) done. Every room is lit." }
    return "\(finished.title) done. Next: \(next.title)\(next.isBuilt ? "" : ", coming soon")."
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      LabBackdrop()
      if split.isSideBySide, next != nil {
        ladder.place(in: split.first)
        nextRoom.place(in: split.second)
      } else {
        ladder.place(in: split.first.union(split.second))
      }
    }
    .contentShape(Rectangle())
    .onTapGesture { finish() }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(summary)
    .accessibilityAddTraits(.isButton)
    .accessibilityHint("Goes back to the journey")
    .accessibilityAction { finish() }
    .task { await play() }
  }

  /// Bottom to top in journey order, so the ladder is drawn top down.
  private var ladder: some View {
    let rooms = Array(RoomID.allCases.reversed())
    return VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(rooms.enumerated()), id: \.element) { index, room in
        stop(room)
        if index + 1 < rooms.count {
          dots(from: rooms[index + 1], to: room)
        }
      }
    }
    .padding(.horizontal, 40)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private func stop(_ room: RoomID) -> some View {
    if room == next {
      HStack(spacing: 20) {
        RoomVignetteView(room: room, size: 96)
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
          Text(room.title)
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(LabColor.primaryInk)
          Text(split.isSideBySide || room.isBuilt ? "Next" : "Next · Coming soon")
            .font(LabFont.caption)
            .foregroundStyle(LabColor.secondaryInk)
        }
      }
    } else if solved.contains(room) {
      HStack(spacing: 20) {
        RoomVignetteView(room: room, size: 76)
          .shadow(color: LabColor.glow.opacity(0.5), radius: 14)
          .frame(width: 96)
        VStack(alignment: .leading, spacing: 8) {
          Text(room.title)
            .font(LabFont.label)
            .foregroundStyle(LabColor.primaryInk)
          FireflyRow(earned: fireflies[room] ?? [], size: 22)
        }
      }
    } else {
      HStack(spacing: 20) {
        RoomVignetteView(room: room, size: 60)
          .frame(width: 96)
        Text(room.title)
          .font(LabFont.label)
          .foregroundStyle(LabColor.secondaryInk)
      }
      .opacity(0.45)
    }
  }

  /// Soft lights between two stops, never a solid line. Warm for the way travelled,
  /// faint for the way ahead; the stretch just travelled lights one dot at a time.
  private func dots(from lower: RoomID, to upper: RoomID) -> some View {
    let isNewStretch = lower == finished && upper == next
    let count = isNewStretch ? travelledDots : 4
    let lit = isNewStretch ? litDots : (solved.contains(lower) && (solved.contains(upper) || upper == next) ? count : 0)
    return VStack(spacing: 8) {
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

  @ViewBuilder
  private var nextRoom: some View {
    if let next {
      VStack(spacing: 18) {
        RoomVignetteView(room: next, size: 150)
          .overlay(Circle().strokeBorder(LabColor.retry.opacity(0.5), lineWidth: 2))
          .shadow(color: LabColor.retry.opacity(0.35), radius: 24)
        Text(next.title)
          .font(LabFont.title)
          .foregroundStyle(LabColor.primaryInk)
        Text(next.isBuilt ? "Next" : "Coming soon")
          .font(LabFont.body)
          .foregroundStyle(LabColor.secondaryInk)
      }
      .opacity(ringShown ? 1 : 0)
      .offset(y: ringShown || reduceMotion ? 0 : 12)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func play() async {
    let start = ContinuousClock.now
    AccessibilityNotification.Announcement(summary).post()
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
