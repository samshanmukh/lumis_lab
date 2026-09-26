import SwiftUI

struct JourneyView: View {
  var model: AppModel
  /// The room just finished: its fireflies light one by one.
  var justFinished: RoomID?
  var start: (RoomID) -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var nudgedRoom: RoomID?
  @State private var litFireflies = 3

  private enum StopState {
    case current
    case done
    case locked
  }

  /// Bottom to top in journey order; a locked stop says which room it follows.
  private var stops: [(room: RoomID, subtitle: String)] {
    RoomID.allCases.reversed().map { room in
      (room, room.previous.map { "After the \($0.shortTitle)" } ?? room.question)
    }
  }

  var body: some View {
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

        ForEach(stops, id: \.room) { stop in
          stopView(stop.room, subtitle: stop.subtitle)
          if let below = stop.room.previous {
            dottedTrail(active: model.room(below).solved)
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
    .background(LabBackdrop())
    .task { await lightFireflies() }
  }

  /// A room is current once the one before it is done; the first room is current from the start.
  private func state(for room: RoomID) -> StopState {
    if model.room(room).solved { return .done }
    if room.opensInOrder, let before = room.previous, !model.room(before).solved { return .locked }
    return .current
  }

  @ViewBuilder
  private func stopView(_ room: RoomID, subtitle: String) -> some View {
    switch state(for: room) {
    case .done:
      doneStop(room)
    case .current:
      currentStop(room, subtitle: room.question, startable: room.isPlayable)
    case .locked:
      lockedStop(room, subtitle: subtitle)
    }
  }

  private func currentStop(_ room: RoomID, subtitle: String, startable: Bool) -> some View {
    Button {
      if startable { start(room) } else { nudge(room) }
    } label: {
      HStack(alignment: .center, spacing: 24) {
        RoomVignetteView(room: room, size: 116)
          .shadow(color: LabColor.glow.opacity(0.65), radius: 24)

        VStack(alignment: .leading, spacing: 5) {
          Text(room.title)
            .font(.system(.title2, design: .rounded, weight: .semibold))
            .foregroundStyle(LabColor.primaryInk)
          if startable {
            Text(subtitle)
              .font(LabFont.caption)
              .foregroundStyle(LabColor.secondaryInk)
              .fixedSize(horizontal: false, vertical: true)
          }
          Group {
            if startable {
              startPill
            } else {
              Text("Coming soon")
                .font(LabFont.label)
                .fixedSize()
                .foregroundStyle(LabColor.secondaryInk)
                .padding(.horizontal, 28)
                .frame(height: 52)
                .background(.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
            }
          }
          .padding(.top, 10)
        }
        Spacer(minLength: 0)
      }
      .offset(x: nudgedRoom == room ? 6 : 0)
      .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(startable ? "\(room.title), \(subtitle)" : "\(room.title), coming soon")
    .accessibilityHint(startable ? "Opens the \(room.title)" : "")
  }

  private func doneStop(_ room: RoomID) -> some View {
    let earned = model.room(room).fireflies
    return Button { start(room) } label: {
      HStack(alignment: .center, spacing: 24) {
        RoomVignetteView(room: room, size: 88)
          .shadow(color: LabColor.glow.opacity(0.35), radius: 14)
          .frame(width: 116)

        VStack(alignment: .leading, spacing: 8) {
          Text(room.title)
            .font(LabFont.label)
            .foregroundStyle(LabColor.primaryInk)
          FireflyRow(earned: earned, size: 24, lightCount: room == justFinished ? litFireflies : 3)
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

  private func lockedStop(_ room: RoomID, subtitle: String) -> some View {
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
          Text(subtitle)
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
    .accessibilityLabel("\(room.title), \(subtitle)")
    .accessibilityHint("Coming later")
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
    guard justFinished != nil, !reduceMotion else { return }
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
