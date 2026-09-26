import SwiftUI

/// A room’s front door (X.0, X.0b, X.0o, X.1). One view that lays out from its container.
/// Rooms played like a laptop hint at the turn: upright on the closed phone the door leans
/// toward sideways, and when the closed phone turns sideways the door lies on its side.
struct DoorView: View {
  var room: RoomID
  var hinge: HingeModel
  var showsHint = true
  var goToMap: () -> Void
  var enterRoom: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var automaticOpening = 0.0
  @State private var isOpening = false
  @State private var hasEntered = false
  @State private var didBeginClosed = false
  @State private var ambient = false
  @State private var lean = 0.0
  @State private var impactTrigger = 0

  private var openFraction: Double {
    if hinge.source == .hinge && didBeginClosed {
      return min(1, max(0, hinge.angle / 110))
    }
    return automaticOpening
  }

  private var phoneIsClosed: Bool {
    hinge.status == .closed && hinge.deviceAngle != nil
  }

  var body: some View {
    GeometryReader { safeArea in
      doorScene(insets: safeArea.safeAreaInsets)
    }
    .sensoryFeedback(.impact(flexibility: .soft), trigger: impactTrigger)
    .onAppear {
      didBeginClosed = hinge.status == .closed
      if !reduceMotion {
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { ambient = true }
      }
    }
    .onChange(of: hinge.angle) { _, angle in
      guard didBeginClosed, hinge.source == .hinge, angle >= 110, !hasEntered else { return }
      finishOpening()
    }
    .onChange(of: hinge.status) { _, status in
      // Opened all the way in one go: play the opening by itself.
      if didBeginClosed, status == .fullyOpen { openDoor() }
    }
    .task(id: room) { await leanLoop() }
  }

  /// Laid out in full-screen coordinates, like the design: the door stands on the floor line
  /// and the hint sits on the floor strip below it.
  private func doorScene(insets: EdgeInsets) -> some View {
    GeometryReader { geometry in
      let size = geometry.size
      let sideways = room.isLaptopRoom && phoneIsClosed && size.width > size.height
      let layout = DoorLayout(size: size, insets: insets, centerX: doorCenterX(in: geometry, insets: insets), sideways: sideways)

      ZStack(alignment: .topLeading) {
        wallBackground(size: size, layout: layout)

        signs(layout: layout, sideways: sideways, insets: insets, size: size)

        if !sideways {
          HStack {
            sconce
            Spacer()
            sconce
          }
          .frame(width: layout.doorWidth + 2 * max(26, layout.doorWidth * 0.1))
          .position(x: layout.center.x, y: layout.floorTop - layout.doorHeight * 0.835)
          .transition(.opacity)
        }

        door(width: layout.doorWidth, height: layout.doorHeight)
          .rotationEffect(.degrees(sideways ? -90 : (showsLean ? -lean : 0)), anchor: sideways ? .center : .bottom)
          .position(layout.center)

        Button(action: openDoor) {
          Color.clear
            .frame(width: layout.tapSize.width, height: layout.tapSize.height)
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open the \(room.title) door")
        .accessibilityHint(phoneIsClosed ? (room.isLaptopRoom ? "Or open your phone like a laptop to go in" : "Or open your phone to go in") : "")
        .position(layout.center)
        .allowsHitTesting(!isOpening && !hasEntered)

        if showsHint {
          Text(hintText(sideways: sideways))
            .font(LabFont.caption)
            .foregroundStyle(LabColor.secondaryInk)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: size.width - insets.leading - insets.trailing - 48, maxHeight: (size.height - layout.floorTop) * 0.7)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: hintText(sideways: sideways))
            .position(x: layout.center.x, y: layout.floorTop + (size.height - layout.floorTop) * 0.45)
            .accessibilityHidden(true)
        }

        MapCapsule(action: goToMap)
          .offset(x: insets.leading + 24, y: insets.top + 16)
          .allowsHitTesting(!isOpening)
      }
      .frame(width: size.width, height: size.height)
      .animation(reduceMotion ? LabMotion.reduced : .spring(duration: 0.6, bounce: 0.15), value: sideways)
    }
    .ignoresSafeArea()
  }

  private var showsLean: Bool {
    room.isLaptopRoom && phoneIsClosed && !reduceMotion
  }

  private func hintText(sideways: Bool) -> String {
    guard phoneIsClosed else { return "Tap the door to go in" }
    guard room.isLaptopRoom else { return "Open your phone to go in" }
    return sideways ? "Now open it like a laptop" : "Turn it sideways, then open"
  }

  @ViewBuilder
  private func signs(layout: DoorLayout, sideways: Bool, insets: EdgeInsets, size: CGSize) -> some View {
    if sideways {
      VStack(alignment: .leading, spacing: 4) {
        Text("Room \(room.number)")
          .font(LabFont.caption)
          .foregroundStyle(LabColor.retry)
        Text(room.signName)
          .font(.system(.title2, design: .rounded, weight: .bold))
          .foregroundStyle(LabColor.primaryInk)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(width: max(120, layout.center.x - layout.doorHeight / 2 - insets.leading - 48), alignment: .leading)
      .offset(x: insets.leading + 40, y: insets.top + 76)
      .transition(.opacity)
    } else {
      // The words sit between the Map capsule and the top of the door, and shrink rather than spill.
      let titleTop = insets.top + 64
      let titleHeight = max(60, layout.floorTop - layout.doorHeight - 16 - titleTop)
      VStack(spacing: 7) {
        Text("Room \(room.number)")
          .font(LabFont.caption)
          .foregroundStyle(LabColor.retry)
        Text(room.signName)
          .font(LabFont.display)
          .foregroundStyle(LabColor.primaryInk)
          .lineLimit(1)
        Text(room.story)
          .font(LabFont.body)
          .foregroundStyle(LabColor.secondaryInk)
          .multilineTextAlignment(.center)
          .lineLimit(3)
      }
      .minimumScaleFactor(0.6)
      .frame(maxWidth: min(size.width - insets.leading - insets.trailing - 80, 580), maxHeight: titleHeight)
      .position(x: layout.center.x, y: titleTop + titleHeight / 2)
      .transition(.opacity)
    }
  }

  private func wallBackground(size: CGSize, layout: DoorLayout) -> some View {
    ZStack(alignment: .topLeading) {
      LabColor.background
      HStack(spacing: size.width * 0.12) {
        ForEach(0..<8, id: \.self) { _ in
          Rectangle().fill(.white.opacity(0.035)).frame(width: 1)
        }
      }
      .frame(width: size.width, height: layout.floorTop)

      Rectangle()
        .fill(LabColor.backgroundBottom)
        .frame(width: size.width, height: size.height - layout.floorTop)
        .offset(y: layout.floorTop)
      Rectangle()
        .fill(LabColor.shadow.opacity(0.6))
        .frame(width: size.width, height: 4)
        .offset(y: layout.floorTop)

      Ellipse()
        .fill(LabColor.softLight.opacity(0.55))
        .frame(width: layout.tapSize.width * 1.17, height: size.height * 0.118)
        .blur(radius: 22)
        .opacity(ambient ? 1 : 0.6)
        .position(x: layout.center.x, y: layout.floorTop + 10)
    }
    .frame(width: size.width, height: size.height)
    .accessibilityHidden(true)
  }

  private var sconce: some View {
    Capsule()
      .fill(LabColor.softLight)
      .frame(width: 14, height: 26)
      .shadow(color: LabColor.glow.opacity(ambient ? 1 : 0.55), radius: 22)
      .accessibilityHidden(true)
  }

  private func door(width: CGFloat, height: CGFloat) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 22)
        .fill(LinearGradient(colors: [LabColor.doorFrame, Color(red: 70 / 255, green: 49 / 255, blue: 168 / 255)], startPoint: .top, endPoint: .bottom))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(LabColor.retry.opacity(0.7), lineWidth: 2))

      Rectangle()
        .fill(LabColor.softLight.opacity(openFraction * 0.9))
        .frame(width: max(4, width * openFraction * 0.75), height: height * 0.94)
        .shadow(color: LabColor.glow, radius: 30)

      HStack(spacing: 0) {
        leaf(width: width * 0.46, height: height * 0.95, left: true)
          .rotation3DEffect(.degrees(-85 * openFraction), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.7)
        leaf(width: width * 0.46, height: height * 0.95, left: false)
          .rotation3DEffect(.degrees(85 * openFraction), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.7)
      }

      Rectangle()
        .fill(LabColor.softLight.opacity(1 - openFraction))
        .frame(width: 3, height: height * 0.95)
        .shadow(color: LabColor.label, radius: 14)

      RoomVignetteView(room: room, size: min(width * 0.46, height * 0.38))
        .opacity(1 - openFraction)
        .overlay(Circle().strokeBorder(LabColor.retry.opacity(1 - openFraction), lineWidth: 2))
        .offset(y: -height * 0.17)
    }
    .frame(width: width, height: height)
    .accessibilityHidden(true)
  }

  private func leaf(width: CGFloat, height: CGFloat, left: Bool) -> some View {
    RoundedRectangle(cornerRadius: 8)
      .fill(LinearGradient(colors: [LabColor.doorLeaf, Color(red: 58 / 255, green: 44 / 255, blue: 154 / 255), Color(red: 43 / 255, green: 30 / 255, blue: 134 / 255)], startPoint: .topLeading, endPoint: .bottomTrailing))
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(LabColor.retry.opacity(0.35), lineWidth: 1)
          .padding(8)
      }
      .overlay(alignment: left ? .trailing : .leading) {
        Capsule()
          .fill(LabColor.primaryInk)
          .frame(width: 7, height: 24)
          .padding(.horizontal, 10)
          .offset(y: height * 0.15)
      }
      .frame(width: width, height: height)
  }

  /// outerDoor lean: every 4 s the door leans 10° toward sideways and settles back (1.2 s).
  private func leanLoop() async {
    guard room.isLaptopRoom else { return }
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(4))
      guard !Task.isCancelled else { return }
      guard showsLean else { continue }
      withAnimation(.easeInOut(duration: 0.6)) { lean = 10 }
      try? await Task.sleep(for: .milliseconds(600))
      withAnimation(.easeInOut(duration: 0.6)) { lean = 0 }
    }
  }

  private func openDoor() {
    guard !isOpening && !hasEntered else { return }
    isOpening = true
    withAnimation(reduceMotion ? LabMotion.reduced : LabMotion.door) {
      automaticOpening = 1
    }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 700))
      finishOpening()
    }
  }

  private func finishOpening() {
    guard !hasEntered else { return }
    hasEntered = true
    impactTrigger += 1
    enterRoom()
  }

  /// The fold when the phone is open like a book, so the seam sits on it;
  /// otherwise the middle of the space beside the system bars.
  private func doorCenterX(in geometry: GeometryProxy, insets: EdgeInsets) -> CGFloat {
    if let region = geometry.reservedRegions(kind: .division, options: .includeInactive).first,
       region.frame.height > region.frame.width {
      return region.frame.midX
    }
    return insets.leading + (geometry.size.width - insets.leading - insets.trailing) / 2
  }
}

/// Where the door and its floor go. Upright, the door stands on the floor line;
/// on its side (the closed phone turned sideways), it lies across the wall like 3.0b.
private struct DoorLayout {
  var doorWidth: CGFloat
  var doorHeight: CGFloat
  var center: CGPoint
  var floorTop: CGFloat
  /// The door’s footprint on screen, which swaps sides when it lies down.
  var tapSize: CGSize

  init(size: CGSize, insets: EdgeInsets, centerX: CGFloat, sideways: Bool) {
    floorTop = size.height * 0.897
    if sideways {
      doorHeight = min(size.width * 0.57, (size.height - insets.top - insets.bottom) * 0.85, 520)
      doorWidth = doorHeight * 0.727
      center = CGPoint(x: insets.leading + (size.width - insets.leading - insets.trailing) * 0.56, y: size.height * 0.54)
      tapSize = CGSize(width: doorHeight, height: doorWidth)
    } else {
      doorHeight = min(size.height * 0.57, 520)
      doorWidth = min(size.width * 0.6, doorHeight * 0.727)
      center = CGPoint(x: centerX, y: floorTop - doorHeight / 2)
      tapSize = CGSize(width: doorWidth, height: doorHeight)
    }
  }
}
