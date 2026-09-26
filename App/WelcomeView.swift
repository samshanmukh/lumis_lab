import SwiftUI

struct WelcomeView: View {
  var isOuter: Bool
  var action: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var awake = false

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        Spacer(minLength: isOuter ? 60 : 20)

        ZStack {
          Circle()
            .fill(LabColor.glow.opacity(0.13))
            .frame(width: min(geometry.size.width * 0.8, 410))
            .blur(radius: 50)
          LumiView(mood: awake ? .wonder : isOuter ? .sleepy : .wonder, radius: min(72, geometry.size.width * 0.14))
        }
        .frame(maxHeight: geometry.size.height * 0.38)

        Text("Lumi’s Lab")
          .font(LabFont.display)
          .foregroundStyle(LabColor.primaryInk)
          .multilineTextAlignment(.center)

        if !isOuter {
          Text("Science you can fold")
            .font(LabFont.body)
            .foregroundStyle(LabColor.secondaryInk)
            .padding(.top, 8)

          Spacer(minLength: 20)

          Text("Lumi is lost in the dark.")
            .font(LabFont.label)
            .foregroundStyle(LabColor.primaryInk)
          Text("Fold your phone to light her way.")
            .font(LabFont.body)
            .foregroundStyle(LabColor.secondaryInk)
            .multilineTextAlignment(.center)
            .padding(.top, 8)
        }

        Spacer(minLength: 24)

        PrimaryLabButton(title: isOuter ? "Play" : "Help Lumi") {
          if !reduceMotion {
            withAnimation(.easeInOut(duration: 0.3)) { awake = true }
            Task { @MainActor in
              try? await Task.sleep(for: .milliseconds(300))
              action()
            }
          } else {
            action()
          }
        }
        .frame(maxWidth: 360)
        .padding(.bottom, 40)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(.horizontal, 40)
    }
    .background(LabBackdrop())
  }
}
