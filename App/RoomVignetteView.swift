import SwiftUI

struct RoomVignetteView: View {
  var room: RoomID
  var size: CGFloat

  var body: some View {
    Image(room.vignetteName)
      .resizable()
      .interpolation(.high)
      .aspectRatio(contentMode: .fit)
      .frame(width: size, height: size)
      .clipShape(Circle())
      .accessibilityLabel(room.title)
  }
}
