import SwiftUI

struct JourneyView: View {
  var model: AppModel
  var lightNewFireflies = false
  var start: (RoomID) -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var nudgedRoom: RoomID?
  @State private var litFireflies = 3

  private enum StopState {
    case current
    case done
    case comingSoon
    case locked
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text("Lumi’s journey")
            .font(LabFont.display)
            .foregroundStyle(LabColor.primaryInk)
            .padding(.bottom, 12)

          Text("\(model.earnedFireflies) of 12 fireflies")
            .font(LabFont.caption)
            .foregroundStyle(LabColor.tertiaryInk)
            .contentTransition(.numericText())
            .padding(.bottom, 28)

          let rooms = Array(RoomID.allCases.reversed())
          ForEach(Array(rooms.enumerated()), id: \.element) { index, room in
            stopView(room)
              .id(room)
            if index + 1 < rooms.count {
              dottedTrail(active: model.state(rooms[index + 1]).solved)
                .padding(.leading, 53)
            }
          }
        }
        .frame(maxWidth: 660, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 40)
        .padding(.bottom, 40)
      }
      .defaultScrollAnchor(.bottom)
      .onAppear {
        // Start where the journey is: the room to play next.
        if let focus = RoomID.allCases.first(where: { state(for: $0) == .current }), focus != .mirror {
          proxy.scrollTo(focus, anchor: .center)
        }
      }
    }
    .background(LabBackdrop())
    .task { await lightFireflies() }
  }

  private func state(for room: RoomID) -> StopState {
    if model.state(room).solved { return .done }
    if model.isStartable(room) { return .current }
    let before = RoomID.allCases.prefix { $0 != room }
    if !room.isBuilt, before.last.map({ model.state($0).solved }) ?? true { return .comingSoon }
    return .locked
  }

  private func subtitle(for room: RoomID) -> String {
    switch state(for: room) {
    case .comingSoon: return "Coming soon"
    case .current:
      switch room {
      case .mirror: return "How many Lumis can two mirrors make?"
      case .marbleRamp: return "Can Lumi’s marble roll far enough?"
      default: return ""
      }
    default:
      // A room opens after the last playable room before it.
      let before = RoomID.allCases.prefix { $0 != room }
      guard let previous = room.isBuilt ? before.last(where: \.isBuilt) : before.last else { return "" }
      return "After \(previous.title)"
    }
  }

  @ViewBuilder
  private func stopView(_ room: RoomID) -> some View {
    switch state(for: room) {
    case .done:
      doneStop(room)
    case .current:
      currentStop(room)
    case .comingSoon, .locked:
      lockedStop(room)
    }
  }

  private func currentStop(_ room: RoomID) -> some View {
    Button {
      start(room)
    } label: {
      HStack(alignment: .center, spacing: 24) {
        RoomVignetteView(room: room, size: 116)
          .shadow(color: LabColor.glow.opacity(0.65), radius: 24)

        VStack(alignment: .leading, spacing: 5) {
          Text(room.title)
            .font(.system(.title2, design: .rounded, weight: .semibold))
            .foregroundStyle(LabColor.primaryInk)
          Text(subtitle(for: room))
            .font(LabFont.caption)
            .foregroundStyle(LabColor.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
          startPill
            .padding(.top, 10)
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(room.title), \(subtitle(for: room))")
    .accessibilityHint("Opens \(room.title)")
  }

  private func doneStop(_ room: RoomID) -> some View {
    let earned = model.state(room).fireflies
    return Button {
      start(room)
    } label: {
      HStack(alignment: .center, spacing: 24) {
        RoomVignetteView(room: room, size: 88)
          .shadow(color: LabColor.glow.opacity(0.35), radius: 14)
          .frame(width: 116)

        VStack(alignment: .leading, spacing: 8) {
          Text(room.title)
            .font(LabFont.label)
            .foregroundStyle(LabColor.primaryInk)
          FireflyRow(earned: earned, size: 24, lightCount: litFireflies)
          startPill
            .padding(.top, 4)
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(room.title), done, \(earned.count) of 3 fireflies")
    .accessibilityHint("Starts the room again from its door")
  }

  private func lockedStop(_ room: RoomID) -> some View {
    Button {
      nudge(room)
    } label: {
      HStack(alignment: .center, spacing: 24) {
        RoomVignetteView(room: room, size: 88)
          .background(Circle().fill(LabColor.backgroundBottom))
          .opacity(0.5)
          .frame(width: 116)

        VStack(alignment: .leading, spacing: 5) {
          Text(room.title)
            .font(LabFont.label)
            .foregroundStyle(LabColor.secondaryInk)
          Text(subtitle(for: room))
            .font(LabFont.caption)
            .foregroundStyle(LabColor.tertiaryInk)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }
      .offset(x: nudgedRoom == room ? 6 : 0)
      .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(room.title), \(subtitle(for: room))")
    .accessibilityHint("Not open yet")
  }

  private var startPill: some View {
    Text("Start")
      .font(LabFont.label)
      .fixedSize()
      .foregroundStyle(LabColor.buttonInk)
      .padding(.horizontal, 28)
      .frame(height: 52)
      .background(LabColor.primaryButton, in: Capsule())
      .shadow(color: LabColor.shadow.opacity(0.35), radius: 8, y: 4)
  }

  private func nudge(_ room: RoomID) {
    guard !reduceMotion else { return }
    withAnimation(.spring(duration: 0.36, bounce: 0.48)) { nudgedRoom = room }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(360))
      withAnimation(.spring(duration: 0.3)) { nudgedRoom = nil }
    }
  }

  /// roomExit: the finished stop’s fireflies light one by one.
  private func lightFireflies() async {
    guard lightNewFireflies, !reduceMotion else { return }
    litFireflies = 0
    try? await Task.sleep(for: .milliseconds(450))
    for count in 1...3 {
      withAnimation(.spring(duration: 0.3, bounce: 0.4)) { litFireflies = count }
      try? await Task.sleep(for: .milliseconds(150))
    }
  }

  private func dottedTrail(active: Bool) -> some View {
    VStack(spacing: 7) {
      ForEach(0..<7, id: \.self) { _ in
        Circle()
          .fill(active ? LabColor.softLight : LabColor.retry.opacity(0.5))
          .frame(width: 5, height: 5)
          .shadow(color: active ? LabColor.softLight : LabColor.retry, radius: 5)
      }
    }
    .frame(height: 68)
    .accessibilityHidden(true)
  }
}
