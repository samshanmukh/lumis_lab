import SwiftUI

struct JourneyView: View {
  var model: AppModel
  var start: () -> Void
  var startMarble: () -> Void
  @State private var nudgedRoom: RoomID?

  private let stops: [(room: RoomID, subtitle: String)] = [
    (.launchAngle, "After the Marble Ramp"),
    (.marbleRamp, "Wake the firefly with the Duo hinge"),
    (.glassPond, "After the Mirror Room"),
    (.mirror, "How many Lumis can two mirrors make?")
  ]

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
          .padding(.bottom, 28)

        ForEach(stops, id: \.room) { stop in
          stopView(stop.room, subtitle: stop.room == .glassPond && model.mirror.solved ? "Coming soon" : stop.subtitle)
          if stop.room != .mirror {
            dottedTrail(active: stop.room == .glassPond && model.mirror.solved)
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
    .background(LabBackdrop())
  }

  private func stopView(_ room: RoomID, subtitle: String) -> some View {
    let active = room == .mirror || room == .marbleRamp
    return Button {
      if room == .mirror {
        start()
      } else if room == .marbleRamp {
        startMarble()
      } else {
        withAnimation(.spring(duration: 0.36, bounce: 0.48)) { nudgedRoom = room }
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(360))
          nudgedRoom = nil
        }
      }
    } label: {
      HStack(alignment: .center, spacing: 24) {
        RoomVignetteView(room: room, size: active ? 116 : 88)
          .opacity(active ? 1 : 0.5)
          .shadow(color: active ? LabColor.glow.opacity(0.65) : .clear, radius: 24)

        VStack(alignment: .leading, spacing: 5) {
          Text(room.title)
            .font(active ? .system(.title2, design: .rounded, weight: .semibold) : LabFont.label)
            .foregroundStyle(active ? LabColor.primaryInk : LabColor.secondaryInk)
          Text(subtitle)
            .font(LabFont.caption)
            .foregroundStyle(active ? LabColor.secondaryInk : LabColor.tertiaryInk)
            .fixedSize(horizontal: false, vertical: true)
          if active {
            Text(model.progress.rooms[room]?.solved == true ? "Replay" : "Start")
              .font(LabFont.label)
              .foregroundStyle(Color(red: 43 / 255, green: 30 / 255, blue: 134 / 255))
              .padding(.horizontal, 28)
              .frame(height: 52)
              .background(LabColor.primaryButton, in: Capsule())
              .padding(.top, 10)
          }
        }
        Spacer(minLength: 0)
      }
      .offset(x: nudgedRoom == room ? 6 : 0)
      .frame(maxWidth: .infinity, minHeight: active ? 136 : 96, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(room.title), \(subtitle)")
    .accessibilityHint(room == .mirror ? "Opens the Mirror Room" : room == .marbleRamp ? "Opens the Marble Ramp" : "Coming later")
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
