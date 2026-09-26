import Foundation
import RevenueCat

enum RevenueCatSetup {
  static let proEntitlement = "lumis_lab_pro"
  static let productIDs: Set<String> = ["monthly", "yearly", "lifetime"]

  /// Configure once, before any purchase or customer-info request.
  static func configure() -> String? {
    #if DEBUG
    let apiKey = "test_VDLQFTNkddWiiXbLWLgZVowCXew"
    #else
    guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatProductionAPIKey") as? String,
          apiKey.hasPrefix("appl_") else {
      return "Add the public App Store RevenueCat API key before distributing this build."
    }
    #endif

    Purchases.configure(withAPIKey: apiKey)
    return nil
  }
}
