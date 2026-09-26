import RevenueCatUI
import SwiftUI

/// 7.7 · Everything a grown-up manages, in one place behind the gate: Plus status, the plans
/// or the subscription, and restoring purchases.
struct GrownUpsView: View {
  var seePlans: () -> Void
  var done: () -> Void

  @Environment(SubscriptionStore.self) private var subscriptions
  @State private var showingCustomerCenter = false

  var body: some View {
    GrownUpsPage { split in
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 16) {
          Text("Grown-ups")
            .font(LabFont.display)
            .foregroundStyle(LabColor.primaryInk)
            .accessibilityAddTraits(.isHeader)
          Spacer(minLength: 0)
          QuietLabButton(title: "Done", action: done)
        }

        list
          .padding(.top, 36)

        if let note {
          Text(note)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(LabColor.secondaryInk)
            .padding(.top, 16)
        }

        Text("Lumi’s Lab collects no personal data. Purchases go through the App Store; RevenueCat keeps an anonymous ID so Plus can be restored.")
          .font(.system(.subheadline, design: .rounded))
          .foregroundStyle(LabColor.tertiaryInk)
          .padding(.top, 28)

        Spacer(minLength: 0)
      }
      .place(in: split.isSideBySide ? split.first : split.column)
    }
    .sheet(isPresented: $showingCustomerCenter) {
      CustomerCenterView()
    }
    .task { await subscriptions.refreshCustomerInfo() }
  }

  private var list: some View {
    VStack(spacing: 0) {
      row("Lumi’s Lab Plus") {
        Text(status)
          .font(.system(.subheadline, design: .rounded))
          .foregroundStyle(LabColor.secondaryInk)
      }
      .accessibilityElement(children: .combine)

      if subscriptions.hasRenewingProPlan {
        separator
        Button {
          showingCustomerCenter = true
        } label: {
          row("Manage subscription") { chevron }
        }
        .buttonStyle(.plain)
      } else if !subscriptions.isPro {
        separator
        Button(action: seePlans) {
          row("See plans") { chevron }
        }
        .buttonStyle(.plain)
        .disabled(subscriptions.setupError != nil)
      }

      separator
      Button {
        Task { await subscriptions.restorePurchases() }
      } label: {
        row("Restore purchases", ink: LabColor.label, weight: .semibold) {
          if subscriptions.isRestoring {
            ProgressView().tint(LabColor.secondaryInk)
          }
        }
      }
      .buttonStyle(.plain)
      .disabled(subscriptions.isRestoring || subscriptions.setupError != nil)
    }
    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
  }

  private func row(
    _ title: String,
    ink: Color = LabColor.primaryInk,
    weight: Font.Weight = .medium,
    @ViewBuilder trailing: () -> some View
  ) -> some View {
    HStack(spacing: 12) {
      Text(title)
        .font(.system(.body, design: .rounded, weight: weight))
        .foregroundStyle(ink)
      Spacer(minLength: 0)
      trailing()
    }
    .padding(.horizontal, 20)
    .frame(minHeight: 60)
    .contentShape(Rectangle())
  }

  private var chevron: some View {
    Image(systemName: "chevron.right")
      .font(.system(.footnote, weight: .semibold))
      .foregroundStyle(LabColor.tertiaryInk)
      .accessibilityHidden(true)
  }

  private var separator: some View {
    Rectangle()
      .fill(.white.opacity(0.1))
      .frame(height: 1)
      .padding(.horizontal, 10)
  }

  private var status: String {
    if subscriptions.isPro {
      return subscriptions.proPlanName.map { "Active · \($0)" } ?? "Active"
    }
    if subscriptions.customerInfo == nil {
      return subscriptions.setupError == nil && subscriptions.customerError == nil ? "Checking…" : "Not checked"
    }
    return "Not active"
  }

  /// Setup problems, a failed status check, or the result of the last restore.
  private var note: String? {
    subscriptions.setupError ?? subscriptions.customerError ?? subscriptions.actionMessage
  }
}
