import SwiftUI

/// The Marble Ramp’s door in the lab’s night sky. Lumi waits beside it, and its round window
/// shows the garden ramp inside. A tap swings the doors open.
struct ChapterDoorView: View {
  var onMap: (() -> Void)?
  var onEnter: () -> Void
  @State private var opening = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private let lumiRadius: CGFloat = 24

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let doorWidth = min(size.width * 0.57, 360)
      ZStack(alignment: .topLeading) {
        LabBackdrop()

        if let onMap {
          MapCapsule(action: onMap)
            .position(x: 66, y: 54)
        }

        VStack(spacing: 7) {
          Text("Room 3")
            .font(LabFont.caption)
            .foregroundStyle(LabColor.tertiaryInk)
          Text("The Marble Ramp")
            .font(LabFont.title)
            .foregroundStyle(LabColor.primaryInk)
            .accessibilityAddTraits(.isHeader)
          Text("A firefly fell asleep at the end of the path. Can Lumi’s marble roll far enough to wake it?")
            .font(LabFont.body)
            .multilineTextAlignment(.center)
            .foregroundStyle(LabColor.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: min(size.width * 0.80, 460))
        .position(x: size.width / 2, y: size.height * 0.18)

        Button(action: openDoor) {
          door(width: doorWidth, height: size.height * 0.55)
        }
        .buttonStyle(.plain)
        .disabled(opening)
        .accessibilityLabel("Open the Marble Ramp door")
        .accessibilityHint("Enter the hinge experiment")
        .position(x: size.width / 2, y: size.height * 0.63)

        lamp
          .position(x: size.width * 0.17, y: size.height * 0.46)
        lamp
          .position(x: size.width * 0.83, y: size.height * 0.46)

        LumiView(mood: opening ? .happy : .wonder, radius: lumiRadius)
          .position(
            x: max(lumiRadius * 1.5, (size.width - doorWidth) / 2 - lumiRadius * 1.7),
            y: size.height * 0.9 - lumiRadius
          )
          .animation(.easeInOut(duration: 0.2), value: opening)

        floor
          .frame(height: size.height * 0.1)
          .position(x: size.width / 2, y: size.height * 0.95)
      }
      .frame(width: size.width, height: size.height)
    }
    .ignoresSafeArea()
  }

  private var floor: some View {
    Rectangle()
      .fill(LinearGradient(colors: [LabColor.floorOuter, LabColor.backgroundBottom], startPoint: .top, endPoint: .bottom))
      .overlay(alignment: .top) {
        Rectangle().fill(LabColor.floorGlow.opacity(0.35)).frame(height: 2)
      }
      .overlay {
        Text("Tap the door to go in")
          .font(LabFont.caption)
          .foregroundStyle(LabColor.secondaryInk)
      }
  }

  private var lamp: some View {
    Capsule()
      .fill(LabColor.softLight)
      .frame(width: 13, height: 20)
      .shadow(color: LabColor.glow, radius: 20)
  }

  private func door(width: CGFloat, height: CGFloat) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 20)
        .fill(LabColor.doorFrame)
        .shadow(color: LabColor.mirrorGlow.opacity(0.42), radius: 24)
      RoundedRectangle(cornerRadius: 14)
        .fill(
          LinearGradient(
            colors: [LabColor.doorLeaf, LabColor.buttonInk],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .padding(16)

      Rectangle()
        .fill(LabColor.softLight)
        .frame(width: 3, height: height - 18)
        .shadow(color: LabColor.glow, radius: 10)

      HStack(spacing: 2) {
        doorLeaf(isLeft: true)
          .rotation3DEffect(.degrees(opening ? -78 : 0), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.5)
        doorLeaf(isLeft: false)
          .rotation3DEffect(.degrees(opening ? 78 : 0), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.5)
      }
      .frame(width: width - 32, height: height * 0.47)
      .offset(y: height * 0.235)

      window(diameter: width * 0.46)
        .offset(y: -height * 0.23)
    }
    .frame(width: width, height: height)
  }

  /// A round window onto the moon garden: the ramp, and the marble waiting at the top.
  private func window(diameter: CGFloat) -> some View {
    Canvas { context, size in
      let floor = size.height * 0.7
      context.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .linearGradient(
          Gradient(colors: [LabColor.labelSurface, LabColor.gardenSky]),
          startPoint: .zero,
          endPoint: CGPoint(x: 0, y: floor)
        )
      )
      for star in Self.windowStars {
        let rect = CGRect(x: star.x * size.width, y: star.y * size.height, width: 2, height: 2)
        context.fill(Path(ellipseIn: rect), with: .color(LabColor.secondaryInk.opacity(0.7)))
      }
      context.fill(
        Path(CGRect(x: 0, y: floor, width: size.width, height: size.height - floor)),
        with: .color(LabColor.pathTop.opacity(0.8))
      )

      let top = CGPoint(x: size.width * 0.2, y: size.height * 0.32)
      let foot = CGPoint(x: size.width * 0.66, y: floor)
      var rail = Path()
      rail.move(to: top)
      rail.addCurve(
        to: foot,
        control1: CGPoint(x: top.x + size.width * 0.1, y: top.y + (floor - top.y) * 0.3),
        control2: CGPoint(x: foot.x - size.width * 0.14, y: floor)
      )
      context.drawGardenRamp(rail, top: top, floor: floor, scale: diameter / 170)
      let marbleRadius = size.width * 0.06
      context.drawMarble(
        at: CGPoint(x: top.x + marbleRadius * 0.9, y: top.y - marbleRadius * 0.7),
        radius: marbleRadius,
        rotation: 0,
        glowBlur: 4
      )
    }
    .frame(width: diameter, height: diameter)
    .clipShape(Circle())
    .overlay {
      Circle().strokeBorder(LabColor.mirrorGlow.opacity(0.7), lineWidth: 6)
    }
    .accessibilityHidden(true)
  }

  private static let windowStars: [(x: CGFloat, y: CGFloat)] = [
    (0.3, 0.14), (0.52, 0.1), (0.7, 0.22), (0.82, 0.38), (0.44, 0.3), (0.6, 0.44)
  ]

  private func doorLeaf(isLeft: Bool) -> some View {
    RoundedRectangle(cornerRadius: 7)
      .fill(LabColor.doorLeaf)
      .overlay {
        RoundedRectangle(cornerRadius: 7)
          .strokeBorder(.white.opacity(0.16), lineWidth: 1)
      }
      .overlay(alignment: isLeft ? .trailing : .leading) {
        Capsule()
          .fill(LabColor.secondaryInk)
          .frame(width: 6, height: 38)
          .padding(.horizontal, 8)
      }
  }

  private func openDoor() {
    guard !opening else { return }
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.7)) { opening = true }
    Task {
      try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 720))
      guard !Task.isCancelled else { return }
      onEnter()
    }
  }
}
