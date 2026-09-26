import SwiftUI

struct LabBackdrop: View {
  var body: some View {
    ZStack {
      LabColor.background
      Canvas { context, size in
        for index in 0..<76 {
          let x = CGFloat((index * 137 + 47) % 997) / 997 * size.width
          let y = CGFloat((index * 281 + 79) % 991) / 991 * size.height
          let diameter: CGFloat = index % 9 == 0 ? 3 : 1.5
          context.fill(
            Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
            with: .color(LabColor.secondaryInk.opacity(index % 3 == 0 ? 0.6 : 0.3))
          )
        }
      }
      .accessibilityHidden(true)
    }
    .ignoresSafeArea()
  }
}
