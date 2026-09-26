import SwiftUI

/// A small passive pill that names part of a scene. Never tappable.
struct SceneLabel: View {
  enum Kind {
    case mirror
    case real
    case reflection
    case goal(met: Bool)
  }

  var text: String
  var kind: Kind

  var body: some View {
    HStack(spacing: 6) {
      if case .real = kind {
        Circle()
          .fill(LabColor.label)
          .frame(width: 6, height: 6)
          .shadow(color: LabColor.label.opacity(0.9), radius: 3)
      }
      Text(text)
        .font(.system(.caption, design: .rounded, weight: isReal ? .medium : .semibold))
        .foregroundStyle(ink)
    }
    .padding(.leading, isReal ? 9 : 10)
    .padding(.trailing, isReal ? 11 : 10)
    .padding(.vertical, 5)
    .background(fill, in: RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(line, lineWidth: 1))
  }

  private var isReal: Bool {
    if case .real = kind { return true }
    return false
  }

  private var ink: Color {
    switch kind {
    case .mirror: LabColor.sceneLabelInk
    case .real: LabColor.softLight.opacity(0.92)
    case .reflection: LabColor.label
    case .goal(let met): met ? LabColor.progress : LabColor.sceneLabelInk
    }
  }

  private var fill: Color {
    switch kind {
    case .real: LabColor.label.opacity(0.12)
    case .goal(let met) where met: LabColor.progress.opacity(0.18)
    default: LabColor.labelSurface.opacity(0.78)
    }
  }

  private var line: Color {
    switch kind {
    case .real: LabColor.lumi.opacity(0.28)
    case .reflection: LabColor.label.opacity(0.55)
    case .goal(let met) where met: LabColor.progress
    default: LabColor.sceneLabelLine.opacity(0.65)
    }
  }
}
