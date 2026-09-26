import SwiftUI

struct DoorView: View {
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
  }

  /// Laid out in full-screen coordinates, like the design: the door stands on the floor line
  /// and the hint sits on the floor strip below it.
  private func doorScene(insets: EdgeInsets) -> some View {
    GeometryReader { geometry in
      let size = geometry.size
      let centerX = doorCenterX(in: geometry, insets: insets)
      let floorTop = size.height * 0.897
      let doorHeight = min(size.height * 0.57, 520)
      let doorWidth = min(size.width * 0.6, doorHeight * 0.727)
      let doorY = floorTop - doorHeight / 2

      ZStack(alignment: .topLeading) {
        wallBackground(size: size, floorTop: floorTop, centerX: centerX, doorWidth: doorWidth)

        VStack(spacing: 7) {
          Text("Room 1")
            .font(LabFont.caption)
            .foregroundStyle(LabColor.retry)
          Text("The Mirror Room")
            .font(LabFont.display)
            .foregroundStyle(LabColor.primaryInk)
          Text("Lumi is alone in the dark. Can mirrors make friends for her?")
            .font(LabFont.body)
            .foregroundStyle(LabColor.secondaryInk)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: min(size.width - insets.leading - insets.trailing - 80, 580))
        .position(x: centerX, y: max(insets.top + 70, (floorTop - doorHeight) * 0.5))

        HStack {
          sconce
          Spacer()
          sconce
        }
        .frame(width: doorWidth + 2 * max(26, doorWidth * 0.1))
        .position(x: centerX, y: floorTop - doorHeight * 0.835)

        door(width: doorWidth, height: doorHeight)
          .position(x: centerX, y: doorY)

        Button(action: openDoor) {
          Color.clear
            .frame(width: doorWidth, height: doorHeight)
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open the Mirror Room door")
        .accessibilityHint(phoneIsClosed ? "Or open your phone to go in" : "")
        .position(x: centerX, y: doorY)
        .allowsHitTesting(!isOpening && !hasEntered)

        if showsHint {
          Text(phoneIsClosed ? "Open your phone to go in" : "Tap the door to go in")
            .font(LabFont.caption)
            .foregroundStyle(LabColor.secondaryInk)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: phoneIsClosed)
            .position(x: centerX, y: floorTop + (size.height - floorTop) * 0.45)
            .accessibilityHidden(true)
        }

        MapCapsule(action: goToMap)
          .offset(x: insets.leading + 24, y: insets.top + 16)
          .allowsHitTesting(!isOpening)
      }
      .frame(width: size.width, height: size.height)
    }
    .ignoresSafeArea()
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

      RoomVignetteView(room: .mirror, size: min(width * 0.46, height * 0.38))
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
