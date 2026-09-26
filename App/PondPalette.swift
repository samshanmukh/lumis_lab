import SwiftUI

enum PondPalette {
  static let nightTop = Color(red: 58 / 255, green: 46 / 255, blue: 158 / 255)
  static let nightBottom = Color(red: 27 / 255, green: 23 / 255, blue: 96 / 255)
  static let violet = Color(red: 86 / 255, green: 71 / 255, blue: 200 / 255)
  static let pond = Color(red: 153 / 255, green: 237 / 255, blue: 246 / 255)
  static let moon = Color(red: 255 / 255, green: 244 / 255, blue: 186 / 255)
  static let light = Color(red: 255 / 255, green: 226 / 255, blue: 151 / 255)
  static let lavender = Color(red: 231 / 255, green: 217 / 255, blue: 255 / 255)
  static let lilac = Color(red: 205 / 255, green: 188 / 255, blue: 255 / 255)

  static let nightGradient = LinearGradient(
    colors: [nightTop, nightBottom],
    startPoint: .top,
    endPoint: .bottom
  )

  static let panelGradient = LinearGradient(
    colors: [Color(red: 57 / 255, green: 105 / 255, blue: 159 / 255), nightBottom],
    startPoint: .top,
    endPoint: .bottom
  )
}
