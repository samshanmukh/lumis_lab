import RevenueCat
import RevenueCatUI
import SwiftUI

/// 7.4 · RevenueCat’s paywall for the current offering, only ever shown behind the parental
/// gate. 7.6 replaces it in place when the store doesn’t finish; a cancelled purchase just
/// stays on the paywall, and its close button ends the sheet.
struct PlusPaywallSheet: View {
  var finish: (PaywallEnding) -> Void

  @Environment(SubscriptionStore.self) private var subscriptions
  @State private var stage = Stage.loading
  @State private var offering: Offering?

  private enum Stage {
    case loading
    case paywall
    case didntFinish
  }

  var body: some View {
    ZStack {
      switch stage {
      case .loading:
        ProgressView()
          .controlSize(.large)
          .tint(LabColor.primaryInk)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(LabBackdrop(showsFireflies: false))
          .accessibilityLabel("Loading Lumi’s Lab Plus")
      case .paywall:
        if let offering {
          PaywallView(offering: offering, displayCloseButton: true)
            .onPurchaseCompleted { info in
              subscriptions.completePurchase(info)
              if subscriptions.isPro { finish(.unlocked) }
            }
            .onRestoreCompleted { info in
              subscriptions.completeRestore(info)
              if subscriptions.isPro { finish(.unlocked) }
            }
            .onPurchaseFailure { error in
              subscriptions.recordPaywallError(error)
              stage = .didntFinish
            }
            .onRestoreFailure { error in
              subscriptions.recordPaywallError(error)
            }
        }
      case .didntFinish:
        LumiMessagePage(
          mood: .calm,
          title: "Nothing was bought",
          line: "The App Store didn’t finish, so nothing changed and nothing was charged."
        ) {
          PrimaryLabButton(title: "Try again", fillsWidth: false) {
            Task { await load() }
          }
          QuietLabButton(title: "Not now") { finish(.notNow) }
        }
      }
    }
    .animation(.easeInOut(duration: 0.2), value: stage)
    .task { await load() }
  }

  private func load() async {
    stage = .loading
    guard await subscriptions.refreshCustomerInfo() else {
      stage = .didntFinish
      return
    }
    // Someone who already has Plus never sees the offer again.
    if subscriptions.isPro {
      finish(.unlocked)
      return
    }
    await subscriptions.refreshOffering()
    offering = subscriptions.currentOffering
    stage = offering == nil ? .didntFinish : .paywall
  }
}
