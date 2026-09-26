import SwiftUI

/// A room’s front door, laid out from its container. Book rooms open straight from the closed
/// phone and the leaves swing with the hinge. Laptop rooms (the Glass Pond, the Marble Ramp) lean
/// toward sideways while the phone is closed and upright, turn on their side with the phone, then
/// open like a lid.
struct DoorView: View {
  var room: RoomID = .mirror
  var hinge: HingeModel
  var showsHint = true
  /// The door was tapped at the previous room’s end, so it opens by itself.
  var opensAtOnce = false
  var goToMap: () -> Void
  var enterRoom: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var automaticOpening = 0.0
  @State private var isOpening = false
  @State private var hasEntered = false
  @State private var didBeginClosed = false
  @State private var ambient = false
  @State private var impactTrigger = 0
  @State private var lean = 0.0
  @State private var turn = 0.0
  @State private var turnArc = 0.0
  @State private var hasPose = false

  private var openFraction: Double {
    if hinge.source == .hinge && didBeginClosed {
      return min(1, max(0, hinge.angle / 110))
    }
    return automaticOpening
  }

  private var phoneIsClosed: Bool {
    hinge.status == .closed && hinge.deviceAngle != nil
  }

  private var phoneIsPartlyOpen: Bool {
    hinge.status == .partiallyOpen && hinge.deviceAngle != nil
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
      if opensAtOnce {
        Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(350))
          openDoor()
        }
      }
    }
    .onChange(of: hinge.angle) { _, angle in
      guard didBeginClosed, hinge.source == .hinge, angle >= 110, !hasEntered else { return }
      finishOpening()
    }
    .onChange(of: hinge.status) { _, status in
      // Closing the phone shuts the door, so opening it again swings the leaves with the hinge.
      if status == .closed { didBeginClosed = true }
      // Opened all the way in one go: play the opening by itself.
      if didBeginClosed, status == .fullyOpen { openDoor() }
    }
  }

  /// Laid out in full-screen coordinates, like the design: the door stands on the floor line
  /// and the hint sits on the floor strip below it. On its side, it floats on the wall.
  private func doorScene(insets: EdgeInsets) -> some View {
    GeometryReader { geometry in
      let size = geometry.size
      let pose = DoorPose(room: room, size: size, closed: phoneIsClosed, partlyOpen: phoneIsPartlyOpen, fold: foldLine(in: geometry))
      let floorTop = size.height * 0.897
      let door = pose.doorSize
      let center = pose.turned ? pose.turnedCenter : CGPoint(x: doorCenterX(in: geometry, insets: insets), y: floorTop - door.height / 2)
      let footprint = pose.turned ? CGSize(width: door.height, height: door.width) : door
      // The words sit between the Map capsule and the top of the door, and shrink rather than spill.
      let titleTop = insets.top + 64
      let titleSpace = CGRect(x: 0, y: titleTop, width: size.width, height: max(60, center.y - footprint.height / 2 - 16 - titleTop))

      ZStack(alignment: .topLeading) {
        wallBackground(size: size, floorTop: floorTop, centerX: center.x, doorWidth: door.width)
        turnedWall(size: size)
          .opacity(turn)

        titleBlock(pose: pose, size: size, insets: insets, centerX: center.x, space: titleSpace)

        HStack {
          sconce
          Spacer()
          sconce
        }
        .frame(width: door.width + 2 * max(26, door.width * 0.1))
        .position(x: center.x, y: floorTop - door.height * 0.835)
        .opacity(1 - turn)

        if pose.turned, pose.closed, !reduceMotion {
          TurnArc(progress: turnArc)
            .stroke(LabColor.softLight.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: footprint.width * 1.05, height: footprint.width * 1.05)
            .position(center)
            .accessibilityHidden(true)
        }

        DoorArt(room: room, width: door.width, height: door.height, openFraction: openFraction)
          .rotationEffect(.degrees(-90 * turn + lean))
          .position(center)

        Button(action: openDoor) {
          Color.clear
            .frame(width: footprint.width, height: footprint.height)
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(room == .mirror ? "Open the Mirror Room door" : "Go in")
        .accessibilityHint(room.playsLikeLaptop ? spokenHint(for: pose) : (phoneIsClosed ? "Or open your phone to go in" : ""))
        .position(center)
        .allowsHitTesting(!isOpening && !hasEntered)

        if showsHint {
          Text(hint(for: pose))
            .font(LabFont.caption)
            .foregroundStyle(LabColor.secondaryInk)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: size.width - insets.leading - insets.trailing - 48, maxHeight: pose.turned ? 40 : (size.height - floorTop) * 0.7)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: hint(for: pose))
            .position(
              x: center.x,
              y: pose.turned
                ? min(size.height - insets.bottom - 30, center.y + footprint.height / 2 + 34)
                : floorTop + (size.height - floorTop) * 0.45
            )
            .accessibilityHidden(true)
        }

        MapCapsule(action: goToMap)
          .offset(x: insets.leading + 24, y: insets.top + 16)
          .allowsHitTesting(!isOpening)
      }
      .frame(width: size.width, height: size.height)
      .onChange(of: pose.turned, initial: true) { _, turned in
        setTurned(turned)
      }
      .task(id: pose.leans && !reduceMotion) {
        await leanLoop(active: pose.leans && !reduceMotion)
      }
    }
    .ignoresSafeArea()
  }

  @ViewBuilder
  private func titleBlock(pose: DoorPose, size: CGSize, insets: EdgeInsets, centerX: CGFloat, space: CGRect) -> some View {
    if pose.turned && pose.closed {
      // X.0b: the sign moves to the top leading corner, beside the door on its side.
      VStack(alignment: .leading, spacing: 4) {
        Text("Room \(room.number)")
          .font(LabFont.caption)
          .foregroundStyle(LabColor.retry)
        Text(room.signName)
          .font(.system(.title2, design: .rounded, weight: .bold))
          .foregroundStyle(LabColor.primaryInk)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(width: max(110, pose.turnedCenter.x - pose.doorSize.height / 2 - insets.leading - 52), alignment: .leading)
      .offset(x: insets.leading + 40, y: insets.top + 76)
      .accessibilityElement(children: .combine)
    } else {
      VStack(spacing: 7) {
        Text("Room \(room.number)")
          .font(LabFont.caption)
          .foregroundStyle(LabColor.retry)
        Text(room.signName)
          .font(LabFont.display)
          .foregroundStyle(LabColor.primaryInk)
          .lineLimit(1)
        Text(room.storyLine)
          .font(LabFont.body)
          .foregroundStyle(LabColor.secondaryInk)
          .multilineTextAlignment(.center)
          .lineLimit(3)
      }
      .minimumScaleFactor(0.6)
      .frame(maxWidth: min(size.width - insets.leading - insets.trailing - 80, 580), maxHeight: space.height)
      .position(x: centerX, y: space.midY)
      .accessibilityElement(children: .combine)
    }
  }

  /// Laptop rooms say how to hold the phone, as the hint on screen does.
  private func spokenHint(for pose: DoorPose) -> String {
    guard pose.closed else { return "" }
    return pose.turned ? "Now open it like a laptop." : "Turn your phone sideways and open it like a laptop."
  }

  private func hint(for pose: DoorPose) -> String {
    if room.playsLikeLaptop, pose.closed {
      return pose.turned ? "Now open it like a laptop" : "Turn it sideways, then open"
    }
    return phoneIsClosed ? "Open your phone to go in" : "Tap the door to go in"
  }

  private func wallBackground(size: CGSize, floorTop: CGFloat, centerX: CGFloat, doorWidth: CGFloat) -> some View {
    ZStack(alignment: .topLeading) {
      LabColor.background
      HStack(spacing: size.width * 0.12) {
        ForEach(0..<8, id: \.self) { _ in
          Rectangle().fill(.white.opacity(0.035)).frame(width: 1)
        }
      }
      .frame(width: size.width, height: floorTop)

      Rectangle()
        .fill(LabColor.backgroundBottom)
        .frame(width: size.width, height: size.height - floorTop)
        .offset(y: floorTop)
      Rectangle()
        .fill(LabColor.shadow.opacity(0.6))
        .frame(width: size.width, height: 4)
        .offset(y: floorTop)

      Ellipse()
        .fill(LabColor.softLight.opacity(0.55))
        .frame(width: doorWidth * 1.17, height: size.height * 0.118)
        .blur(radius: 22)
        .opacity(ambient ? 1 : 0.6)
        .position(x: centerX, y: floorTop + 10)
    }
    .frame(width: size.width, height: size.height)
    .accessibilityHidden(true)
  }

  /// On its side the door floats on a plain wall: no floor, no sconces.
  private func turnedWall(size: CGSize) -> some View {
    ZStack {
      LabColor.background
      RadialGradient(colors: [LabColor.retry.opacity(0.14), .clear], center: .center, startRadius: 0, endRadius: max(size.width, size.height) * 0.55)
    }
    .frame(width: size.width, height: size.height)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private var sconce: some View {
    Capsule()
      .fill(LabColor.softLight)
      .frame(width: 14, height: 26)
      .shadow(color: LabColor.glow.opacity(ambient ? 1 : 0.55), radius: 22)
      .accessibilityHidden(true)
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

  /// turn: the door turns with the phone (0.6 s spring) and a short arc of light traces it.
  /// A door that is already on its side when it appears just shows that way.
  private func setTurned(_ turned: Bool) {
    let target = turned ? 1.0 : 0.0
    defer { hasPose = true }
    guard target != turn else { return }
    guard hasPose, !reduceMotion else {
      withAnimation(hasPose ? LabMotion.reduced : nil) {
        turn = target
        turnArc = turned ? 1 : 0
      }
      return
    }
    turnArc = 0
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { turn = target }
    if turned {
      withAnimation(.easeOut(duration: 0.6)) { turnArc = 1 }
    }
  }

  /// outerDoor lean: every 4 s the upright door leans 10° toward sideways and settles back.
  private func leanLoop(active: Bool) async {
    guard active else {
      withAnimation(.easeInOut(duration: 0.3)) { lean = 0 }
      return
    }
    while !Task.isCancelled {
      try? await Task.sleep(for: .milliseconds(2800))
      guard !Task.isCancelled else { break }
      withAnimation(.easeInOut(duration: 0.6)) { lean = -10 }
      try? await Task.sleep(for: .milliseconds(600))
      withAnimation(.easeInOut(duration: 0.6)) { lean = 0 }
      try? await Task.sleep(for: .milliseconds(600))
    }
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

  /// The fold across the screen when the phone opens like a laptop.
  private func foldLine(in geometry: GeometryProxy) -> CGFloat? {
    guard let region = geometry.reservedRegions(kind: .division, options: .includeInactive).first,
          region.frame.width > region.frame.height else { return nil }
    return region.frame.midY
  }
}

/// How a door stands for the phone’s pose. Only laptop rooms ever turn.
private struct DoorPose {
  var room: RoomID
  var size: CGSize
  var closed: Bool
  var partlyOpen: Bool
  var fold: CGFloat?

  private var wide: Bool { size.width > size.height }

  /// On its side: the closed phone turned sideways (X.0b), or open like a laptop (X.1).
  var turned: Bool {
    guard room.playsLikeLaptop else { return false }
    return (closed && wide) || (partlyOpen && !wide)
  }

  /// Closed and upright, a laptop room’s door leans toward the turn.
  var leans: Bool { room.playsLikeLaptop && closed && !wide }

  /// Upright, the door is sized from its container. On its side it keeps the size it had with
  /// the phone upright, so the turn doesn’t shrink it.
  var doorSize: CGSize {
    let long = turned ? max(size.width, size.height) : size.height
    let short = turned ? min(size.width, size.height) : size.width
    let height = min(long * 0.57, 520)
    return CGSize(width: min(short * 0.6, height * 0.727), height: height)
  }

  /// Beside the sign on the outer display; with its seam on the fold when open like a laptop.
  var turnedCenter: CGPoint {
    if closed {
      return CGPoint(x: size.width * 0.563, y: size.height * 0.54)
    }
    return CGPoint(x: size.width / 2, y: fold ?? size.height / 2)
  }
}

/// The double door itself: frame, two leaves, the lit seam, pale handles and the room’s window.
struct DoorArt: View {
  var room: RoomID
  var width: CGFloat
  var height: CGFloat
  var openFraction: Double

  var body: some View {
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
        .clipShape(Circle())
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
}

/// A short arc of light with an arrowhead, tracing a quarter turn. Counterclockwise from the top
/// toward the leading side by default; clockwise traces the turn toward the trailing side.
struct TurnArc: Shape {
  var progress: Double
  var clockwise = false

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    var path = Path()
    guard progress > 0.01 else { return path }
    let radius = min(rect.width, rect.height) / 2
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let direction: Double = clockwise ? 1 : -1
    let start = -90 + 12 * direction
    let end = start + 78 * progress * direction
    func point(_ degrees: Double) -> CGPoint {
      let radians = degrees * .pi / 180
      return CGPoint(x: center.x + radius * CGFloat(cos(radians)), y: center.y + radius * CGFloat(sin(radians)))
    }
    let steps = 24
    path.move(to: point(start))
    for index in 1...steps {
      path.addLine(to: point(start + (end - start) * Double(index) / Double(steps)))
    }
    // The arrowhead points along the turn.
    let tip = point(end)
    let heading = (end + 90 * direction) * .pi / 180
    for side in [-0.45, 0.45] {
      let angle = heading + .pi + side
      path.move(to: tip)
      path.addLine(to: CGPoint(x: tip.x + 10 * CGFloat(cos(angle)), y: tip.y + 10 * CGFloat(sin(angle))))
    }
    return path
  }
}
