import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class SubscriptionStore {
  private(set) var customerInfo: CustomerInfo?
  private(set) var currentOffering: Offering?
  private(set) var customerError: String?
  private(set) var offeringError: String?
  private(set) var actionMessage: String?
  private(set) var isRestoring = false
  private(set) var isPurchasing = false
  private var isObservingCustomerInfo = false

  let setupError: String?

  init(setupError: String?) {
    self.setupError = setupError
  }

  private var activeProEntitlement: EntitlementInfo? {
    guard let entitlement = customerInfo?.entitlements.all[RevenueCatSetup.proEntitlement],
          entitlement.isActive else { return nil }
    return entitlement
  }

  var isPro: Bool {
    activeProEntitlement != nil
  }

  var proExpirationDate: Date? {
    activeProEntitlement?.expirationDate
  }

  var hasRenewingProPlan: Bool {
    guard let productID = activeProEntitlement?.productIdentifier else { return false }
    return productID == "monthly" || productID == "yearly"
  }

  /// The active plan as grown-ups see it: Monthly, Yearly or Lifetime.
  var proPlanName: String? {
    switch activeProEntitlement?.productIdentifier {
    case "monthly": "Monthly"
    case "yearly": "Yearly"
    case "lifetime": "Lifetime"
    default: nil
    }
  }

  var missingProductIDs: Set<String> {
    guard let currentOffering else { return RevenueCatSetup.productIDs }
    let offeredIDs = Set(currentOffering.availablePackages.map(\.storeProduct.productIdentifier))
    return RevenueCatSetup.productIDs.subtracting(offeredIDs)
  }

  func start() async {
    guard setupError == nil, !isObservingCustomerInfo else { return }
    isObservingCustomerInfo = true
    defer { isObservingCustomerInfo = false }
    await refresh()
    for await info in Purchases.shared.customerInfoStream {
      receive(info)
    }
  }

  func refresh() async {
    guard setupError == nil else { return }
    await refreshCustomerInfo()
    await refreshOffering()
  }

  @discardableResult
  func refreshCustomerInfo() async -> Bool {
    guard setupError == nil else { return false }
    do {
      receive(try await Purchases.shared.customerInfo())
      customerError = nil
      return true
    } catch {
      customerError = "Couldn’t check purchases. Check your connection and try again. \(error.localizedDescription)"
      return false
    }
  }

  func refreshOffering() async {
    guard setupError == nil else { return }
    do {
      currentOffering = try await Purchases.shared.offerings().current
      offeringError = currentOffering == nil
        ? "No current offering is configured in RevenueCat."
        : nil
    } catch {
      offeringError = "Couldn’t load plans. Check your connection and try again. \(error.localizedDescription)"
    }
  }

  /// For custom plan buttons. The RevenueCat paywall performs this purchase itself.
  func purchase(_ package: Package) async {
    guard setupError == nil, !isPurchasing else { return }
    isPurchasing = true
    defer { isPurchasing = false }
    actionMessage = nil

    do {
      let result = try await Purchases.shared.purchase(package: package)
      guard !result.userCancelled else { return }
      completePurchase(result.customerInfo)
      if !isPro {
        actionMessage = "Purchase completed, but Plus access is not active yet. Try Restore Purchases."
      }
    } catch {
      guard (error as? RevenueCat.ErrorCode) != .purchaseCancelledError else { return }
      actionMessage = "Purchase failed. Please try again. \(error.localizedDescription)"
    }
  }

  func restorePurchases() async {
    guard setupError == nil, !isRestoring else { return }
    isRestoring = true
    defer { isRestoring = false }
    actionMessage = nil

    do {
      completeRestore(try await Purchases.shared.restorePurchases())
    } catch {
      actionMessage = "Couldn’t restore purchases. Check your connection and try again. \(error.localizedDescription)"
    }
  }

  func receive(_ info: CustomerInfo) {
    customerInfo = info
    customerError = nil
  }

  func completePurchase(_ info: CustomerInfo) {
    receive(info)
    actionMessage = nil
  }

  func completeRestore(_ info: CustomerInfo) {
    receive(info)
    actionMessage = isPro
      ? "Lumi’s Lab Plus access was restored."
      : "No active Lumi’s Lab Plus purchase was found for this account."
  }

  func recordPaywallError(_ error: Error) {
    actionMessage = "The purchase couldn’t be completed. Please try again. \(error.localizedDescription)"
  }
}
