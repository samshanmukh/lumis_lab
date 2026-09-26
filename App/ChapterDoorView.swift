import SwiftUI

struct ChapterDoorView: View {
  var onMap: (() -> Void)?
  var onEnter: () -> Void
  @State private var opening = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      ZStack(alignment: .topLeading) {
        LinearGradient(
          colors: [Color(red: 0.22, green: 0.18, blue: 0.61), Color(red: 0.10, green: 0.08, blue: 0.35)],
          startPoint: .top,
          endPoint: .bottom
        )

        ForEach(1..<6, id: \.self) { index in
          Rectangle()
            .fill(.white.opacity(0.035))
            .frame(width: 1, height: size.height)
            .position(x: size.width * CGFloat(index) / 6, y: size.height / 2)
        }

        if onMap != nil {
          Button("‹  Map") { onMap?() }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(.white.opacity(0.12), in: Capsule())
            .position(x: 66, y: 54)
        }

        VStack(spacing: 7) {
          Text("Room 3")
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(.white.opacity(0.72))
          Text("The Marble Ramp")
            .font(.system(.title, design: .rounded, weight: .bold))
          Text("A firefly fell asleep at the end of the path. Can Lumi’s marble roll far enough to wake it?")
            .font(.system(.subheadline, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.76))
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: min(size.width * 0.80, 460))
        .position(x: size.width / 2, y: size.height * 0.18)

        Button(action: openDoor) {
          door(width: min(size.width * 0.57, 360), height: size.height * 0.55)
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

        Rectangle()
          .fill(
            LinearGradient(
              colors: [Color(red: 0.13, green: 0.10, blue: 0.39), Color(red: 0.09, green: 0.07, blue: 0.30)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .overlay(alignment: .top) {
            Rectangle().fill(.black.opacity(0.2)).frame(height: 3)
          }
          .frame(height: size.height * 0.1)
          .overlay {
            Text("Tap the door to go in")
              .font(.system(.subheadline, design: .rounded))
              .foregroundStyle(.white.opacity(0.74))
          }
          .position(x: size.width / 2, y: size.height * 0.95)
      }
      .frame(width: size.width, height: size.height)
    }
    .ignoresSafeArea()
  }

  private var lamp: some View {
    Capsule()
      .fill(Color(red: 1, green: 0.95, blue: 0.66))
      .frame(width: 13, height: 20)
      .shadow(color: Color(red: 1, green: 0.78, blue: 0.42), radius: 20)
  }

  private func door(width: CGFloat, height: CGFloat) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 20)
        .fill(Color(red: 0.42, green: 0.34, blue: 0.81))
        .shadow(color: Color(red: 0.68, green: 0.54, blue: 1).opacity(0.42), radius: 24)
      RoundedRectangle(cornerRadius: 14)
        .fill(
          LinearGradient(
            colors: [Color(red: 0.33, green: 0.28, blue: 0.77), Color(red: 0.17, green: 0.13, blue: 0.52)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .padding(16)

      Rectangle()
        .fill(Color(red: 1, green: 0.89, blue: 0.57))
        .frame(width: 3, height: height - 18)
        .shadow(color: Color(red: 1, green: 0.79, blue: 0.39), radius: 10)

      HStack(spacing: 2) {
        doorLeaf(isLeft: true)
          .rotation3DEffect(.degrees(opening ? -78 : 0), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.5)
        doorLeaf(isLeft: false)
          .rotation3DEffect(.degrees(opening ? 78 : 0), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.5)
      }
      .frame(width: width - 32, height: height * 0.47)
      .offset(y: height * 0.235)

      Circle()
        .fill(Color(red: 0.16, green: 0.13, blue: 0.47))
        .frame(width: width * 0.46)
        .overlay {
          Circle().strokeBorder(Color(red: 0.68, green: 0.61, blue: 1).opacity(0.7), lineWidth: 6)
        }
        .overlay {
          ZStack {
            Path { path in
              path.move(to: CGPoint(x: width * 0.16, y: width * 0.33))
              path.addLine(to: CGPoint(x: width * 0.36, y: width * 0.20))
              path.addLine(to: CGPoint(x: width * 0.36, y: width * 0.33))
              path.closeSubpath()
            }
            .fill(Color(red: 0.75, green: 0.67, blue: 1).opacity(0.54))
            Circle()
              .fill(Color(red: 1, green: 0.79, blue: 0.39))
              .frame(width: 18, height: 18)
              .shadow(color: Color(red: 1, green: 0.7, blue: 0.31), radius: 13)
              .offset(x: -width * 0.05, y: width * 0.055)
          }
        }
        .offset(y: -height * 0.23)
    }
    .frame(width: width, height: height)
  }

  private func doorLeaf(isLeft: Bool) -> some View {
    RoundedRectangle(cornerRadius: 7)
      .fill(Color(red: 0.32, green: 0.27, blue: 0.72))
      .overlay {
        RoundedRectangle(cornerRadius: 7)
          .strokeBorder(Color(red: 0.66, green: 0.58, blue: 0.97).opacity(0.42), lineWidth: 1)
      }
      .overlay(alignment: isLeft ? .trailing : .leading) {
        Capsule()
          .fill(Color(red: 0.88, green: 0.82, blue: 1))
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
