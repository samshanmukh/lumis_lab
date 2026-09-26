import SwiftUI

struct PrimaryLabButton: View {
  var title: String
  var fillsWidth = true
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(LabFont.label)
        .foregroundStyle(Color(red: 43 / 255, green: 30 / 255, blue: 134 / 255))
        .fixedSize(horizontal: !fillsWidth, vertical: false)
        .padding(.horizontal, fillsWidth ? 0 : 30)
        .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 56)
        .background(LabColor.primaryButton, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 28))
    }
    .buttonStyle(PrimaryLabButtonStyle())
  }
}

private struct PrimaryLabButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .animation(.snappy, value: configuration.isPressed)
  }
}

struct QuietLabButton: View {
  var title: String
  var systemImage: String?
  var action: () -> Void

  var body: some View {
    Group {
      if let systemImage {
        Button(title, systemImage: systemImage, action: action)
      } else {
        Button(title, action: action)
      }
    }
    .font(LabFont.label)
    .foregroundStyle(LabColor.primaryInk)
    .fixedSize()
    .padding(.horizontal, 8)
    .frame(minHeight: 56)
    .contentShape(Rectangle())
  }
}

struct MapCapsule: View {
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      Label("Map", systemImage: "chevron.left")
        .font(LabFont.caption)
        .foregroundStyle(LabColor.secondaryInk)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

struct ProgressDots: View {
  var current: Int

  var body: some View {
    HStack(spacing: 6) {
      ForEach(1...6, id: \.self) { index in
        Capsule()
          .fill(index < current ? LabColor.progress.opacity(0.5) : index == current ? LabColor.progress : .white.opacity(0.22))
          .frame(width: index == current ? 22 : 8, height: 8)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Room progress")
    .accessibilityValue("Step \(current) of 6")
  }
}
