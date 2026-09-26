import SwiftUI

struct JourneyView: View {
  var model: AppModel
  var lightNewFireflies = false
  var start: () -> Void
  var startMarble: () -> Void
  var askGrownUp: (RoomID) -> Void
  var openGrownUps: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(SubscriptionStore.self) private var subscriptions
  @State private var nudgedRoom: RoomID?
  @State private var litFireflies = 3

  private enum StopState {
    case current
    case done
    case locked
    /// Part of Lumi’s Lab Plus, which this family doesn’t have yet.
    case plus
  }

  private let stops: [(room: RoomID, subtitle: String)] = [
    (.launchAngle, "After the Marble Ramp"),
    (.marbleRamp, "Wake the firefly with the Duo hinge"),
    (.glassPond, "After the Mirror Room"),
    (.mirror, "How many Lumis can two mirrors make?")
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ViewThatFits(in: .horizontal) {
          header(compactGrownUps: false)
          header(compactGrownUps: true)
        }
        .padding(.bottom, 12)

        Text("\(model.earnedFireflies) of 12 fireflies")
          .font(LabFont.caption)
          .foregroundStyle(LabColor.tertiaryInk)
          .contentTransition(.numericText())
          .padding(.bottom, 28)

        ForEach(stops, id: \.room) { stop in
          stopView(stop.room, subtitle: stop.subtitle)
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
    .defaultScrollAnchor(.bottom)
    .background(LabBackdrop())
    .task { await lightFireflies() }
  }

  private func state(for room: RoomID) -> StopState {
    if room.needsPlus && !subscriptions.isPro { return .plus }
    return switch room {
    case .mirror: model.mirror.solved ? .done : .current
    case .glassPond: model.mirror.solved ? .current : .locked
    case .marbleRamp: model.progress.rooms[.marbleRamp]?.solved == true ? .done : .current
    default: .locked
    }
  }

  @ViewBuilder
  private func stopView(_ room: RoomID, subtitle: String) -> some View {
    switch state(for: room) {
    case .done:
      doneStop(room)
    case .current:
      currentStop(room, subtitle: subtitle, startable: room == .mirror || room == .marbleRamp)
    case .locked:
      // With Plus, Launch Angle is open but not built yet.
      lockedStop(room, subtitle: room.needsPlus ? "Coming soon" : subtitle)
    case .plus:
      plusStop(room)
    }
  }

  private func currentStop(_ room: RoomID, subtitle: String, startable: Bool) -> some View {
    Button {
      if startable { open(room) } else { nudge(room) }
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
    let earned = model.progress.rooms[room]?.fireflies ?? []
    return Button { open(room) } label: {
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

  /// 7.1 · A Plus room shows a lemon lock and who can open it, never a price.
  private func plusStop(_ room: RoomID) -> some View {
    Button {
      askGrownUp(room)
    } label: {
      HStack(alignment: .center, spacing: 24) {
        RoomVignetteView(room: room, size: 88)
          .background(Circle().fill(LabColor.backgroundBottom))
          .opacity(0.5)
          .overlay(alignment: .topTrailing) {
            PlusLockBadge()
              .offset(x: 4)
          }
          .frame(width: 116)

        VStack(alignment: .leading, spacing: 5) {
          Text(room.title)
            .font(LabFont.label)
            .foregroundStyle(LabColor.primaryInk)
          Text("Part of Lumi’s Lab Plus. Ask a grown-up to open it.")
            .font(LabFont.caption)
            .foregroundStyle(LabColor.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
          Text("Ask a grown-up")
            .font(LabFont.label)
            .fixedSize()
            .foregroundStyle(LabColor.primaryInk)
            .padding(.horizontal, 28)
            .frame(height: 56)
            .glassCapsule()
            .padding(.top, 10)
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(room.title), part of Lumi’s Lab Plus, locked")
    .accessibilityHint("Asks a grown-up to open it")
  }

  /// The title with Grown-ups beside it; the button drops its words where the title would wrap.
  private func header(compactGrownUps: Bool) -> some View {
    HStack(spacing: 16) {
      Text("Lumi’s journey")
        .font(LabFont.display)
        .foregroundStyle(LabColor.primaryInk)
      Spacer(minLength: 0)
      grownUpsButton(compact: compactGrownUps)
    }
  }

  /// Opens the parental gate, then everything a grown-up manages.
  private func grownUpsButton(compact: Bool) -> some View {
    Button(action: openGrownUps) {
      Group {
        if compact {
          Image(systemName: "person.crop.circle")
            .frame(width: 44, height: 44)
        } else {
          Label("Grown-ups", systemImage: "person.crop.circle")
            .padding(.horizontal, 16)
            .frame(height: 44)
        }
      }
      .font(.system(.subheadline, design: .rounded, weight: .semibold))
      .foregroundStyle(LabColor.primaryInk)
      .fixedSize()
      .glassCapsule()
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Grown-ups")
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

  private func open(_ room: RoomID) {
    if room == .marbleRamp { startMarble() } else { start() }
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

/// A small lemon lock on a Plus room’s stop.
private struct PlusLockBadge: View {
  var body: some View {
    Image(systemName: "lock.fill")
      .font(.system(size: 12, weight: .bold))
      .foregroundStyle(LabColor.label)
      .frame(width: 30, height: 30)
      .background(LabColor.labelSurface.opacity(0.9), in: Circle())
      .overlay(Circle().strokeBorder(LabColor.label, lineWidth: 1.2))
      .accessibilityHidden(true)
  }
}
