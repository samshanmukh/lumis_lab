import SwiftUI

/// 7.2 · A kid-safe handoff: what’s locked and who can open it. No prices, plans or pressure,
/// and nothing on this screen is a purchase.
struct AskGrownUpView: View {
  var room: RoomID
  var grownUp: () -> Void
  var notNow: () -> Void

  var body: some View {
    LumiMessagePage(
      mood: .calm,
      title: "Ask a grown-up",
      line: "\(room.title) is part of Lumi’s Lab Plus. A grown-up can open it for you."
    ) {
      PrimaryLabButton(title: "I’m a grown-up", fillsWidth: false, action: grownUp)
      QuietLabButton(title: "Not now", action: notNow)
    }
  }
}
