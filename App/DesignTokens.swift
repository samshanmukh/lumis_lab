import SwiftUI

enum LabColor {
  static let backgroundTop = Color(hex: 0x3A2E9E)
  static let backgroundBottom = Color(hex: 0x1B1760)
  static let primaryInk = Color(hex: 0xF4F1EA)
  static let secondaryInk = Color(hex: 0xD6CFFF)
  static let tertiaryInk = Color(hex: 0xB3A8F0)
  static let correct = Color(hex: 0x7FF0C8)
  static let retry = Color(hex: 0xB8A4FF)
  static let progress = Color(hex: 0x6FE7FF)
  static let label = Color(hex: 0xFFE066)
  static let labelSurface = Color(hex: 0x241A78)
  static let lumi = Color(hex: 0xFFE3A6)
  static let glow = Color(hex: 0xFFC56B)
  static let amber = Color(hex: 0xFFB54D)
  static let softLight = Color(hex: 0xFFF1C4)
  static let doorFrame = Color(hex: 0x6A58DD)
  static let doorLeaf = Color(hex: 0x5647C8)
  static let buttonInk = Color(hex: 0x2B1E86)
  static let mirrorGlow = Color(hex: 0xC3B0FF)
  static let mirrorEdge = Color(hex: 0xFFF3DA)
  static let sceneLabelInk = Color(hex: 0xDCD6FF)
  static let sceneLabelLine = Color(hex: 0xCFC8FF)
  static let glassFace = Color(hex: 0xE6E3FF)
  static let floorInner = Color(hex: 0x7B6BE8)
  static let floorOuter = Color(hex: 0x34289A)
  static let floorGlow = Color(hex: 0xA58CFF)
  static let panel = Color(hex: 0x4536A8)
  static let shadow = Color(hex: 0x120E4A)

  // The Glass Pond
  static let skyMiddle = Color(hex: 0x4631A8)
  static let skyHorizon = Color(hex: 0x7A56C8)
  static let horizonGlow = Color(hex: 0xE39AD8)
  static let moonCore = Color(hex: 0xFFFEF6)
  static let moonHalo = Color(hex: 0xFFF1CC)
  static let moonRim = Color(hex: 0xFFE2A8)
  static let moonGlow = Color(hex: 0xFFE9B8)
  static let moonCrater = Color(hex: 0xF3DDB0)
  static let farHills = Color(hex: 0x3A2C9A)
  static let nearHills = Color(hex: 0x2A1F7E)
  static let reed = Color(hex: 0x1C1560)
  static let glassTop = Color(hex: 0xA8F4F7)
  static let glassShallow = Color(hex: 0x5CC7E8)
  static let glassMiddle = Color(hex: 0x3C82D6)
  static let glassDeep = Color(hex: 0x2E3FA6)
  static let glassAqua = Color(hex: 0x9FF3EC)
  static let glassLine = Color(hex: 0xCFFFF8)
  static let shaft = Color(hex: 0xDFFFFA)
  static let caustic = Color(hex: 0xE6FFFB)
  static let mote = Color(hex: 0xC8FFF3)
  static let floorTop = Color(hex: 0x23307E)
  static let floorBottom = Color(hex: 0x1A2266)
  static let crystalPink = Color(hex: 0xFFD9F0)
  static let crystalLavender = Color(hex: 0xE2D6FF)
  static let crystalAqua = Color(hex: 0xCFFBFF)
  static let crystalIce = Color(hex: 0xEFFFFF)
  static let padTop = Color(hex: 0x3C9A86)
  static let padBottom = Color(hex: 0x1A5057)
  static let padSheen = Color(hex: 0xBDF5E0)
  static let beamGlow = Color(hex: 0xFFD68A)
  static let beamCore = Color(hex: 0xFFF8EA)
  static let lilyGlow = Color(hex: 0xFFB0DA)
  static let budTop = Color(hex: 0xFFE3F3)
  static let budBottom = Color(hex: 0xC9B6FF)
  static let lilyPetalTop = Color(hex: 0xFFF3FA)
  static let lilyPetalBottom = Color(hex: 0xD9C6FF)
  static let lilyInner = Color(hex: 0xFFD1EC)
  static let vineStalk = Color(hex: 0x1F6E66)
  static let leafTop = Color(hex: 0x7FE6C9)
  static let leafBottom = Color(hex: 0x2A8C7A)
  static let vineGlass = Color(hex: 0xE8FFFB)
  static let vineCore = Color(hex: 0x9FE8E8)
  static let vineEdge = Color(hex: 0xDFFFFA)
  static let vineShadow = Color(hex: 0x7FF0E0)

  static let background = LinearGradient(
    colors: [backgroundTop, backgroundBottom],
    startPoint: .top,
    endPoint: .bottom
  )

  static let primaryButton = LinearGradient(
    colors: [Color(hex: 0xE4DEFF), Color(hex: 0xD0C7FF)],
    startPoint: .top,
    endPoint: .bottom
  )
}

enum LabFont {
  static let display = Font.system(.largeTitle, design: .rounded, weight: .bold)
  static let title = Font.system(.title, design: .rounded, weight: .bold)
  static let body = Font.system(.body, design: .rounded)
  static let label = Font.system(.body, design: .rounded, weight: .semibold)
  static let caption = Font.system(.footnote, design: .rounded, weight: .medium)
  static let barLabel = Font.system(.caption2, design: .rounded, weight: .medium)
  static func readout(size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
}

enum LabMotion {
  static let step = Animation.spring(response: 0.42, dampingFraction: 0.9)
  static let room = Animation.spring(response: 0.5, dampingFraction: 0.86)
  static let door = Animation.spring(response: 0.7, dampingFraction: 0.86)
  static let hinge = Animation.spring(response: 0.12, dampingFraction: 1)
  static let panel = Animation.spring(response: 0.4, dampingFraction: 0.9)
  static let reduced = Animation.easeInOut(duration: 0.2)
}

private extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }
}
