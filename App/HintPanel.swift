import SwiftUI

/// The custom hint panel (5.7). Levels escalate: a nudge, a clue, then Show me.
/// While a demo plays it shrinks to a bar with Stop, then says “Your turn”.
struct HintPanel: View {
  var content: HintContent
  var state: HintState
  var gotIt: () -> Void
  var anotherHint: () -> Void
  var showMe: () -> Void
  var stop: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var demoProgress = 0.0

  var body: some View {
    Group {
      switch state.phase {
      case .panel: panel
      case .showing: demoBar
      case .yourTurn: yourTurn
      }
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background {
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .fill(LinearGradient(
          colors: [Color(red: 79 / 255, green: 65 / 255, blue: 180 / 255).opacity(0.98), Color(red: 55 / 255, green: 45 / 255, blue: 131 / 255).opacity(0.98)],
          startPoint: .top,
          endPoint: .bottom
        ))
        .shadow(color: .black.opacity(0.35), radius: 15, y: 6)
    }
    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1))
    .gesture(
      DragGesture(minimumDistance: 20).onEnded { value in
        if value.translation.height > 40, state.phase == .panel { gotIt() }
      }
    )
    .animation(reduceMotion ? LabMotion.reduced : .spring(duration: 0.35, bounce: 0.1), value: state)
  }

  private var panel: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 10) {
        Text("Hint")
          .font(.system(.subheadline, design: .rounded, weight: .semibold))
          .foregroundStyle(LabColor.label)
        if content.levels.count > 1 {
          LevelDots(level: state.level, count: content.levels.count)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(content.levels.count > 1 ? "Hint, level \(state.level) of \(content.levels.count)" : "Hint")
      .accessibilityAddTraits(.isHeader)

      HStack(alignment: .top, spacing: 12) {
        LumiView(mood: .calm, radius: 15)
          .frame(width: 40, height: 40)
          .accessibilityHidden(true)
        Text(content.levels[state.level - 1])
          .font(LabFont.body)
          .foregroundStyle(LabColor.primaryInk)
          .fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .id(state.level)
          .transition(.opacity)
      }

      HStack(spacing: 12) {
        if state.level == content.levels.count, let title = content.showMeTitle {
          PrimaryLabButton(title: title, fillsWidth: false, action: showMe)
          GlassLabButton(title: "Got it", action: gotIt)
        } else {
          GlassLabButton(title: "Got it", action: gotIt)
          if state.level < content.levels.count {
            QuietLabButton(title: "Another hint", action: anotherHint)
          }
        }
      }
    }
  }

  private var demoBar: some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Showing you…")
          .font(.system(.subheadline, design: .rounded, weight: .semibold))
          .foregroundStyle(LabColor.label)
        Capsule()
          .fill(.white.opacity(0.2))
          .overlay(alignment: .leading) {
            Rectangle()
              .fill(LabColor.label)
              .scaleEffect(x: demoProgress, anchor: .leading)
          }
          .clipShape(Capsule())
          .frame(height: 6)
          .accessibilityHidden(true)
      }
      QuietLabButton(title: "Stop", systemImage: "stop.fill", action: stop)
    }
    .onAppear {
      demoProgress = 0
      withAnimation(.linear(duration: 4)) { demoProgress = 1 }
    }
  }

  private var yourTurn: some View {
    HStack(spacing: 12) {
      LumiView(mood: .happy, radius: 15)
        .frame(width: 40, height: 40)
        .accessibilityHidden(true)
      Text("Your turn")
        .font(.system(.title3, design: .rounded, weight: .semibold))
        .foregroundStyle(LabColor.primaryInk)
    }
    .frame(minHeight: 56)
  }
}

/// Hint levels reached so far: lemon for used, faint for the ones left.
private struct LevelDots: View {
  var level: Int
  var count: Int

  var body: some View {
    HStack(spacing: 6) {
      ForEach(1...count, id: \.self) { index in
        Circle()
          .fill(index <= level ? LabColor.label : .white.opacity(0.25))
          .frame(width: 8, height: 8)
      }
    }
  }
}
