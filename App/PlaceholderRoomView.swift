import SwiftUI

struct PlaceholderRoomView: View {
  var hinge: HingeModel
  var map: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      HStack(spacing: 24) {
        MapCapsule(action: map)
        ProgressDots(current: 1)
      }
      Spacer()
      Text("Mirror Room")
        .font(LabFont.display)
        .foregroundStyle(LabColor.primaryInk)
        .frame(maxWidth: .infinity)
      if hinge.usesDial {
        AngleDial(hinge: hinge)
          .frame(maxWidth: .infinity)
      }
      Spacer()
    }
    .padding(40)
    .background(LabBackdrop())
  }
}
