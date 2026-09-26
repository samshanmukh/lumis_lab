import SwiftUI

struct DoorView: View {
  var hinge: HingeModel
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

  var body: some View {
    GeometryReader { geometry in
      let foldX = divisionCenter(in: geometry)
      let doorWidth = min(geometry.size.width * 0.6, 420)
      let doorHeight = min(geometry.size.height * 0.52, 500)
      let doorY = geometry.size.height * 0.62

      ZStack(alignment: .topLeading) {
        wallBackground

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
        .frame(maxWidth: min(geometry.size.width - 100, 580))
        .position(x: foldX, y: geometry.size.height * 0.19)

        HStack {
          sconce
          Spacer()
          sconce
        }
        .frame(width: min(geometry.size.width * 0.72, 600))
        .position(x: foldX, y: doorY - doorHeight * 0.24)

        door(width: doorWidth, height: doorHeight)
          .position(x: foldX, y: doorY)

        HStack(spacing: 80) {
          doorTapTarget
          doorTapTarget
        }
        .frame(width: doorWidth, height: doorHeight)
        .position(x: foldX, y: doorY)
        .allowsHitTesting(!isOpening && !hasEntered)

        Text(hinge.status == .closed && hinge.source == .hinge ? "Open your phone to go in" : "Tap the door to go in")
          .font(LabFont.caption)
          .foregroundStyle(LabColor.secondaryInk)
          .frame(maxWidth: .infinity)
          .position(x: geometry.size.width / 2, y: geometry.size.height * 0.86)

        MapCapsule(action: goToMap)
          .padding(.leading, 24)
          .padding(.top, 16)
          .allowsHitTesting(!isOpening)
      }
    }
    .background(LabColor.background)
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
  }

  @ViewBuilder
  private var wallBackground: some View {
    GeometryReader { geometry in
      ZStack {
        LabColor.background
        HStack(spacing: geometry.size.width * 0.12) {
          ForEach(0..<8, id: \.self) { _ in
            Rectangle().fill(.white.opacity(0.035)).frame(width: 1)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        VStack {
          Spacer()
          Rectangle()
            .fill(LabColor.softLight.opacity(ambient ? 0.65 : 0.32))
            .frame(height: 4)
            .shadow(color: LabColor.glow, radius: 16)
          Rectangle().fill(LabColor.backgroundBottom).frame(height: geometry.size.height * 0.09)
        }
      }
    }
    .ignoresSafeArea()
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

  private var doorTapTarget: some View {
    Button("Open the Mirror Room door") { openDoor() }
      .font(.caption)
      .foregroundStyle(.clear)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
      .accessibilityLabel("Open the Mirror Room door")
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

  private func divisionCenter(in geometry: GeometryProxy) -> CGFloat {
    if #available(iOS 27.1, *) {
      if let region = geometry.reservedRegions(kind: .division, options: .includeInactive).first {
        return region.frame.midX
      }
    }
    return geometry.size.width / 2
  }
}
