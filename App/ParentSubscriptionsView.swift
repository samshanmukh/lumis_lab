import RevenueCatUI
import SwiftUI

struct ParentSubscriptionsView: View {
  @Environment(SubscriptionStore.self) private var subscriptions
  @State private var showingPaywall = false
  @State private var showingCustomerCenter = false
  @State private var loadingPaywall = false

  var body: some View {
    Form {
      Section("Lumi’s Lab Plus") {
        LabeledContent("Access", value: subscriptions.isPro ? "Active" : "Inactive")
        if let expirationDate = subscriptions.proExpirationDate {
          LabeledContent("Current period ends", value: expirationDate.formatted(date: .abbreviated, time: .omitted))
        }
        if let setupError = subscriptions.setupError {
          Text(setupError).foregroundStyle(.secondary)
        } else if let customerError = subscriptions.customerError {
          Text(customerError).foregroundStyle(.secondary)
          Button("Retry status check", systemImage: "arrow.clockwise") {
            Task { await subscriptions.refreshCustomerInfo() }
          }
        }
      }

      if !subscriptions.isPro {
        Section("Plans") {
          if let offering = subscriptions.currentOffering {
            ForEach(offering.availablePackages, id: \.identifier) { package in
              LabeledContent(package.storeProduct.localizedTitle,
                             value: package.storeProduct.localizedPriceString)
            }
            if !subscriptions.missingProductIDs.isEmpty {
              Text("Some plans are temporarily unavailable.")
                .foregroundStyle(.secondary)
            }
          } else if let offeringError = subscriptions.offeringError {
            Text(offeringError).foregroundStyle(.secondary)
          } else {
            ProgressView("Loading plans…")
          }

          Button("View plans", systemImage: "sparkles") {
            Task { await openPaywall() }
          }
          .disabled(loadingPaywall || subscriptions.setupError != nil)

          if loadingPaywall {
            ProgressView("Checking access…")
          }
        }
      }

      Section("Purchases") {
        Button("Restore purchases", systemImage: "arrow.clockwise") {
          Task { await subscriptions.restorePurchases() }
        }
        .disabled(subscriptions.isRestoring || subscriptions.setupError != nil)

        if subscriptions.isRestoring {
          ProgressView("Restoring purchases…")
        }

        if subscriptions.hasRenewingProPlan {
          Button("Manage subscription", systemImage: "person.crop.circle") {
            showingCustomerCenter = true
          }
        }

        if let actionMessage = subscriptions.actionMessage {
          Text(actionMessage).foregroundStyle(.secondary)
        }
      }
    }
    .sheet(isPresented: $showingPaywall) {
      if let offering = subscriptions.currentOffering {
        PaywallView(offering: offering, displayCloseButton: true)
          .onPurchaseCompleted { info in
            subscriptions.receive(info)
            showingPaywall = false
          }
          .onRestoreCompleted { info in
            subscriptions.receive(info)
            if subscriptions.isPro { showingPaywall = false }
          }
          .onPurchaseFailure { error in
            subscriptions.recordPaywallError(error)
          }
          .onRestoreFailure { error in
            subscriptions.recordPaywallError(error)
          }
      }
    }
    .sheet(isPresented: $showingCustomerCenter) {
      CustomerCenterView()
    }
  }

  private func openPaywall() async {
    guard !loadingPaywall else { return }
    loadingPaywall = true
    defer { loadingPaywall = false }

    guard await subscriptions.refreshCustomerInfo() else { return }
    guard !subscriptions.isPro else { return }
    await subscriptions.refreshOffering()
    guard subscriptions.currentOffering != nil else { return }
    showingPaywall = true
  }
}
