import SwiftUI

@main
struct LumisLabApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @State private var subscriptions: SubscriptionStore

  init() {
    let setupError = RevenueCatSetup.configure()
    _subscriptions = State(initialValue: SubscriptionStore(setupError: setupError))
  }

  var body: some Scene {
    WindowGroup {
      LabRootView()
        .environment(subscriptions)
        .task {
          await subscriptions.start()
        }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active {
            Task { await subscriptions.refresh() }
          }
        }
    }
  }
}
