import SwiftUI

struct PondDoorView: View {
  var session: GlassPondSession

  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var ambientGlow = false

  private var doorAnimation: Animation {
    if reduceMotion { return .easeOut(duration: 0.2) }
    return session.inputMode == .hinge
      ? .spring(response: 0.12, dampingFraction: 1)
      : .spring(response: 0.7, dampingFraction: 0.85)
  }

  var body: some View {
    GeometryReader { geometry in
      let scale = min(geometry.size.width / 466, geometry.size.height / 678)

      ZStack {
        LinearGradient(
          colors: [Color(red: 0.23, green: 0.18, blue: 0.62), Color(red: 0.15, green: 0.11, blue: 0.49)],
          startPoint: .top,
          endPoint: .bottom
        )
        .ignoresSafeArea()

        doorArtwork
          .frame(width: 466, height: 678)
          .scaleEffect(scale)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .ignoresSafeArea()
    .task(id: reduceMotion) {
      ambientGlow = false
      guard !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
        ambientGlow = true
      }
    }
  }

  private var doorArtwork: some View {
    ZStack(alignment: .topLeading) {
      wall
      floor

      Button("Map", systemImage: "map") { dismiss() }
        .labelStyle(.iconOnly)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 42, height: 42)
        .background(.white.opacity(0.16), in: Circle())
        .position(x: 45, y: 46)

      Image("DoorLight")
        .resizable()
        .frame(width: 374, height: 124)
        .opacity(ambientGlow ? 1 : 0.62)
        .position(x: 233, y: 618)
        .accessibilityHidden(true)

      sconce(at: 65)
      sconce(at: 401)

      doorFrame
      pondBeyondDoor
      doorLeaf(isLeft: true)
      doorLeaf(isLeft: false)

      Rectangle()
        .fill(Color(red: 1, green: 0.94, blue: 0.77))
        .frame(width: 3, height: 372)
        .shadow(color: PondPalette.light.opacity(0.9), radius: ambientGlow ? 15 : 8)
        .opacity(1 - session.doorOpenProgress)
        .position(x: 233, y: 422)

      window
        .opacity(1 - session.doorOpenProgress)

      VStack(spacing: 4) {
        Text("Room 2")
          .font(.system(size: 15, weight: .semibold, design: .rounded))
          .foregroundStyle(Color(red: 0.84, green: 0.81, blue: 1))
        Text("The Glass Pond")
          .font(.system(size: 30, weight: .bold, design: .rounded))
          .foregroundStyle(Color(red: 0.96, green: 0.95, blue: 0.92))
        Text("Lumi fell into a pond of magic glass.\nCan her light wake the moon lily?")
          .font(.system(size: 16, weight: .medium, design: .rounded))
          .multilineTextAlignment(.center)
          .foregroundStyle(Color(red: 0.84, green: 0.81, blue: 1))
          .lineSpacing(2)
          .padding(.top, 2)
      }
      .frame(width: 430)
      .position(x: 233, y: 122)

      Text("Turn it sideways, then open")
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .foregroundStyle(Color(red: 0.96, green: 0.95, blue: 0.92))
        .frame(width: 430)
        .position(x: 233, y: 644)

      Button {
        session.openDoor()
      } label: {
        Color.clear
          .frame(width: 282, height: 388)
          .contentShape(RoundedRectangle(cornerRadius: 18))
      }
      .buttonStyle(.plain)
      .position(x: 233, y: 414)
      .accessibilityLabel("Open the Glass Pond door")
      .accessibilityHint("Double-tap, or open iPhone Duo to enter the room")
    }
    .animation(doorAnimation, value: session.doorOpenProgress)
  }

  private var wall: some View {
    ZStack(alignment: .topLeading) {
      LinearGradient(
        colors: [Color(red: 0.23, green: 0.17, blue: 0.60), Color(red: 0.15, green: 0.11, blue: 0.49)],
        startPoint: .top,
        endPoint: .bottom
      )
      ForEach(0..<6) { index in
        Rectangle()
          .fill(.white.opacity(0.045))
          .frame(width: 1, height: 608)
          .position(x: CGFloat(index) * 96, y: 304)
      }
    }
    .frame(width: 466, height: 608)
  }

  private var floor: some View {
    LinearGradient(
      colors: [Color(red: 0.12, green: 0.09, blue: 0.4), Color(red: 0.07, green: 0.05, blue: 0.27)],
      startPoint: .top,
      endPoint: .bottom
    )
    .frame(width: 466, height: 70)
    .position(x: 233, y: 643)
  }

  private func sconce(at x: CGFloat) -> some View {
    ZStack {
      Image("DoorSconceWash")
        .resizable()
        .frame(width: 98, height: 122)
        .opacity(ambientGlow ? 1 : 0.7)
      Image("DoorSconce")
        .resizable()
        .frame(width: 40, height: 44)
    }
    .position(x: x, y: 284)
    .accessibilityHidden(true)
  }

  private var doorFrame: some View {
    UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18)
      .fill(
        LinearGradient(
          colors: [Color(red: 0.42, green: 0.35, blue: 0.87), Color(red: 0.27, green: 0.19, blue: 0.66)],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .strokeBorder(Color(red: 0.76, green: 0.69, blue: 1).opacity(0.8), lineWidth: 2)
      .frame(width: 282, height: 388)
      .position(x: 233, y: 414)
  }

  private var pondBeyondDoor: some View {
    ZStack {
      LinearGradient(
        colors: [PondPalette.nightTop, PondPalette.violet, PondPalette.pond],
        startPoint: .top,
        endPoint: .bottom
      )
      Image("DoorVignette")
        .resizable()
        .scaledToFill()
        .scaleEffect(1.5)
    }
    .frame(width: 250, height: 368)
    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
    .opacity(session.doorOpenProgress)
    .position(x: 233, y: 422)
    .accessibilityHidden(true)
  }

  private func doorLeaf(isLeft: Bool) -> some View {
    ZStack {
      Rectangle()
        .fill(
          LinearGradient(
            colors: [Color(red: 0.38, green: 0.29, blue: 0.81), Color(red: 0.23, green: 0.16, blue: 0.59)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
      RoundedRectangle(cornerRadius: 7)
        .strokeBorder(Color(red: 0.69, green: 0.61, blue: 0.98).opacity(0.5), lineWidth: 1.5)
        .frame(width: 97, height: 164)
        .offset(y: 89)
      Capsule()
        .fill(Color(red: 0.88, green: 0.81, blue: 1))
        .frame(width: 6, height: 34)
        .offset(x: isLeft ? 57 : -57, y: 41)
    }
    .frame(width: 125, height: 372)
    .rotation3DEffect(
      .degrees((isLeft ? -1 : 1) * 110 * session.doorOpenProgress),
      axis: (x: 0, y: 1, z: 0),
      anchor: isLeft ? .leading : .trailing,
      perspective: 0.35
    )
    .position(x: isLeft ? 170.5 : 295.5, y: 422)
  }

  private var window: some View {
    ZStack {
      Image("DoorGlow")
        .resizable()
        .frame(width: 224, height: 224)
      Image("DoorWindow")
        .resizable()
        .frame(width: 128, height: 128)
      Image("DoorVignette")
        .resizable()
        .frame(width: 112, height: 112)
    }
    .position(x: 233, y: 332)
    .accessibilityHidden(true)
  }
}
