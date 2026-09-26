import SwiftUI

/// X.9, on to the next room: the four rooms as a ladder in journey order, with the path lit
/// from the finished room to the next one. When the next room is built, its door waits on the
/// other half: turn the phone or tap it. Otherwise it says “Coming soon” and heads back to the
/// journey after 2.5 s or a tap.
struct RoomEndView: View {
  var finished: RoomID
  var app: AppModel
  var split: FoldSplit
  var leave: () -> Void
  /// Goes to the next room’s door; true when its door was tapped here, so it opens by itself.
  var enterNext: ((_ tapped: Bool) -> Void)?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var litDots = 0
  @State private var ringShown = false
  @State private var litSlots: Int?
  @State private var nextShown = false
  @State private var didLeave = false

  private let travelledDots = 5

  private var next: RoomID? { finished.next }
  private var nextIsPlayable: Bool { next?.isPlayable == true && enterNext != nil }
  private var earnedTotal: Int { app.earnedFireflies }
  private var earnedHere: Int { app.room(finished).fireflies.count }

  var body: some View {
    ZStack(alignment: .topLeading) {
      LabBackdrop()
      ladder
        .padding(.top, nextIsPlayable ? 56 : 0)
        .place(in: split.first)
      nextHalf.place(in: split.second)
      if nextIsPlayable {
        MapCapsule(action: finish)
          .offset(x: split.first.minX + 24, y: split.first.minY + 16)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture { if !nextIsPlayable { finish() } }
    .accessibilityElement(children: nextIsPlayable ? .contain : .ignore)
    .accessibilityLabel(announcement)
    .accessibilityAddTraits(nextIsPlayable ? [] : .isButton)
    .accessibilityHint(nextIsPlayable ? "" : "Goes back to the journey")
    .accessibilityAction { if !nextIsPlayable { finish() } }
    .onChange(of: split.isSideBySide) { wasSideBySide, sideBySide in
      // Turning the phone to laptop (or closing it) goes straight to the next room’s door.
      if nextIsPlayable, wasSideBySide, !sideBySide, !didLeave {
        didLeave = true
        enterNext?(false)
      }
    }
    .task { await play() }
  }

  private var announcement: String {
    guard let next else { return "\(finished.title) done." }
    return "\(finished.title) done. Next: \(next.title)\(nextIsPlayable ? "" : ", coming soon")."
  }

  // MARK: The ladder

  private var ladder: some View {
    GeometryReader { proxy in
      let natural: CGFloat = 470
      let scale = min(1, proxy.size.height / natural)
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(RoomID.allCases.reversed())) { room in
          stop(room)
          if let below = room.previous {
            dots(between: room, and: below)
          }
        }
      }
      .scaleEffect(scale, anchor: .leading)
      .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
    }
    .padding(.horizontal, 24)
  }

  private enum StopState { case done, next, later }

  private func state(of room: RoomID) -> StopState {
    if room == next { return .next }
    if room == finished || app.room(room).solved { return .done }
    return .later
  }

  @ViewBuilder
  private func stop(_ room: RoomID) -> some View {
    switch state(of: room) {
    case .done:
      HStack(spacing: 20) {
        RoomVignetteView(room: room, size: 66)
          .background(Circle().fill(LabColor.backgroundBottom))
          .shadow(color: LabColor.glow.opacity(0.45), radius: 12)
          .frame(width: 104)
        VStack(alignment: .leading, spacing: 6) {
          Text(room.title)
            .font(LabFont.label)
            .foregroundStyle(LabColor.primaryInk)
          FireflyRow(earned: app.room(room).fireflies, size: 22)
        }
      }
    case .next:
      HStack(spacing: 20) {
        RoomVignetteView(room: room, size: 88)
          .background(Circle().fill(LabColor.backgroundBottom))
          .overlay {
            Circle()
              .strokeBorder(LabColor.retry.opacity(0.8), lineWidth: 2)
              .padding(-8)
              .opacity(ringShown ? 1 : 0)
          }
          .shadow(color: LabColor.retry.opacity(ringShown ? 0.5 : 0), radius: 18)
          .scaleEffect(ringShown ? 1 : 0.86)
          .frame(width: 104, height: 112)
        VStack(alignment: .leading, spacing: 4) {
          Text(room.title)
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(LabColor.primaryInk)
          Text(room.isPlayable ? "Next" : "Next · Coming soon")
            .font(LabFont.caption)
            .foregroundStyle(LabColor.sceneLabelLine)
        }
      }
    case .later:
      HStack(spacing: 20) {
        RoomVignetteView(room: room, size: 56)
          .background(Circle().fill(LabColor.backgroundBottom))
          .frame(width: 104)
        Text(room.title)
          .font(LabFont.label)
          .foregroundStyle(LabColor.tertiaryInk)
      }
      .opacity(0.55)
    }
  }

  /// Soft lights between two stops, never a solid line: lit for the way travelled, lighting one
  /// by one from the finished room to the next, faint ahead.
  private func dots(between upper: RoomID, and lower: RoomID) -> some View {
    let isNewPath = upper == next && lower == finished
    let travelled = state(of: upper) == .done && state(of: lower) == .done
    let count = isNewPath ? travelledDots : 3
    return VStack(spacing: 8) {
      ForEach(0..<count, id: \.self) { index in
        let isLit = travelled || (isNewPath && count - index <= litDots)
        Circle()
          .fill(isLit ? LabColor.softLight : LabColor.retry.opacity(0.35))
          .frame(width: 5, height: 5)
          .shadow(color: isLit ? LabColor.softLight : .clear, radius: 4)
      }
    }
    .frame(width: 104)
    .padding(.vertical, 8)
    .accessibilityHidden(true)
  }

  // MARK: The other half

  @ViewBuilder
  private var nextHalf: some View {
    if let next, nextIsPlayable {
      nextDoor(next)
    } else {
      fireflyCount
    }
  }

  /// The next room’s door, with a turn arc when it is played like a laptop.
  private func nextDoor(_ room: RoomID) -> some View {
    GeometryReader { proxy in
      let height = min(proxy.size.height * 0.62, 300)
      let width = height * 0.727
      VStack(spacing: 28) {
        Button {
          guard !didLeave else { return }
          didLeave = true
          enterNext?(true)
        } label: {
          DoorArt(room: room, width: width, height: height, openFraction: 0)
            .overlay(alignment: .topTrailing) {
              if room.playsLikeLaptop && split.isSideBySide {
                TurnArc(progress: nextShown ? 1 : 0, clockwise: true)
                  .stroke(LabColor.softLight.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                  .frame(width: width * 1.2, height: width * 1.2)
                  .offset(x: width * 0.55, y: -width * 0.2)
                  .accessibilityHidden(true)
              }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(room.title) door")
        .accessibilityHint("Opens the door")

        Text(room.playsLikeLaptop && split.isSideBySide ? "Turn your phone, then tap the door" : "Tap the door to go in")
          .font(LabFont.caption)
          .foregroundStyle(LabColor.secondaryInk)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .opacity(nextShown ? 1 : 0)
      .offset(y: nextShown || reduceMotion ? 0 : 12)
    }
  }

  /// Every firefly so far as a row of twelve slots, the new ones filling in.
  private var fireflyCount: some View {
    VStack(spacing: 18) {
      if split.isSideBySide, let next {
        RoomVignetteView(room: next, size: 120)
          .overlay(Circle().strokeBorder(LabColor.retry.opacity(0.5), lineWidth: 2))
          .shadow(color: LabColor.retry.opacity(0.35), radius: 24)
        Text(next.title)
          .font(LabFont.title)
          .foregroundStyle(LabColor.primaryInk)
        Text("Coming soon")
          .font(LabFont.body)
          .foregroundStyle(LabColor.secondaryInk)
          .padding(.bottom, 12)
      }
      ViewThatFits(in: .horizontal) {
        slots(in: [Array(0..<12)])
        slots(in: [Array(0..<6), Array(6..<12)])
      }
      Text("\(earnedTotal) of 12 fireflies")
        .font(LabFont.body)
        .foregroundStyle(LabColor.secondaryInk)
        .contentTransition(.numericText())
    }
    .opacity(nextShown ? 1 : 0)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func slots(in rows: [[Int]]) -> some View {
    let lit = litSlots ?? earnedTotal
    return VStack(spacing: 10) {
      ForEach(rows, id: \.self) { row in
        HStack(spacing: 10) {
          ForEach(row, id: \.self) { index in
            FireflyView(lit: index < lit, size: 30)
              .scaleEffect(index < lit ? 1 : 0.9)
          }
        }
      }
    }
    .fixedSize()
    .accessibilityHidden(true)
  }

  // MARK: Motion

  /// trail: the dots light one by one (0.05 s stagger), the next room’s ring fades in, then the
  /// new fireflies fill their slots (0.1 s stagger) or the next door rises in.
  private func play() async {
    let start = ContinuousClock.now
    litSlots = max(0, earnedTotal - earnedHere)
    AccessibilityNotification.Announcement(announcement).post()
    if reduceMotion {
      litDots = travelledDots
      withAnimation(LabMotion.reduced) {
        ringShown = true
        nextShown = true
        litSlots = earnedTotal
      }
    } else {
      try? await Task.sleep(for: .milliseconds(250))
      for dot in 1...travelledDots {
        withAnimation(.easeOut(duration: 0.12)) { litDots = dot }
        try? await Task.sleep(for: .milliseconds(50))
      }
      withAnimation(.spring(duration: 0.4, bounce: 0.2)) { ringShown = true }
      try? await Task.sleep(for: .milliseconds(300))
      withAnimation(.spring(duration: 0.45, bounce: 0.15)) { nextShown = true }
      while let lit = litSlots, lit < earnedTotal, !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation(.spring(duration: 0.3, bounce: 0.4)) { litSlots = lit + 1 }
      }
    }
    // A built next room waits for the turn or a tap; otherwise head back to the journey.
    guard !nextIsPlayable else { return }
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
