# RevenueCat in Lumi’s Lab

This repository includes a runnable SwiftUI purchase flow. Its complete code examples are [`Project.json`](../Project.json), [`LumisLabApp.swift`](../App/LumisLabApp.swift), [`RevenueCatSetup.swift`](../App/RevenueCatSetup.swift), [`SubscriptionStore.swift`](../App/SubscriptionStore.swift), [`GrownUpsFlow.swift`](../App/GrownUpsFlow.swift), [`ParentGateView.swift`](../App/ParentGateView.swift), [`PlusPaywallSheet.swift`](../App/PlusPaywallSheet.swift), and [`GrownUpsView.swift`](../App/GrownUpsView.swift). Which rooms need Plus is `RoomID.needsPlus` in `GrownUpsFlow.swift`; today that is only Launch Angle.

## 1. Install both Swift Package products

`Project.json` declares the [RevenueCat SPM mirror](https://github.com/RevenueCat/purchases-ios-spm.git) with an up-to-next-major rule starting at `5.83.0`, and links **RevenueCat** and **RevenueCatUI** to the iOS app target. Bitrig generates the Xcode project from this file. In a conventional Xcode project, use **File → Add Package Dependencies**, paste the same URL, choose **Up to Next Major Version**, and select both package products for the app target. See [RevenueCat’s installation guide](https://www.revenuecat.com/docs/getting-started/installation/ios#install-via-swift-package-manager).

## 2. Configure the SDK once

`LumisLabApp.init()` calls `RevenueCatSetup.configure()` before any customer-info or offering request. Debug builds use your Test Store public SDK key, `test_VDLQFTNkddWiiXbLWLgZVowCXew`. The release path reads `RevenueCatProductionAPIKey` from the generated Info.plist and refuses to configure unless it has an `appl_` prefix. Add your **public Apple SDK key** to that `Project.json` Info.plist property when the App Store app is ready. RevenueCat [intentionally crashes release builds with a Test Store key](https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store#test-store-api-keys-in-release-builds), so keep the two keys separate. Never put a RevenueCat secret API key in the app.

The app currently starts with an anonymous RevenueCat user. If it later adds accounts, configure or call `Purchases.shared.logIn(appUserID)` after sign-in and refresh `CustomerInfo`; use a stable, non-guessable user ID. Avoid logging out during normal navigation, since that can change which RevenueCat customer owns purchases. See [RevenueCat’s user identification guide](https://www.revenuecat.com/docs/customers/identifying-customers).

## 3. Set up the catalog

The [Lumis Lab RevenueCat Test Store catalog](https://app.revenuecat.com/projects/c4ecf93e/product-catalog/products) is configured for the Debug key. The products are:

| Product ID | Type and duration | USD price | Offering package |
| --- | --- | ---: | --- |
| `monthly` | Auto-renewing subscription, 1 month | $4.99 | `$rc_monthly` |
| `yearly` | Auto-renewing subscription, 1 year | $39.99 | `$rc_annual` |
| `lifetime` | Non-consumable, one-time | $79.99 | `$rc_lifetime` |

All three products are attached to `lumis_lab_pro` and mapped to the corresponding packages in the current [`default` offering](https://app.revenuecat.com/projects/c4ecf93e/product-catalog/offerings/ofrng453c680666). The [published Lumi’s Lab Plus paywall](https://app.revenuecat.com/projects/c4ecf93e/paywalls/wff1ba4df5ceb44722/builder) uses the supplied ivory-and-indigo design with monthly, yearly, and lifetime choices. Its price labels use RevenueCat’s `{{ product.price }}` variable, so the displayed price comes from the selected product. The app shows no prices of its own: prices appear only on the paywall, behind the parental gate. See [product configuration](https://www.revenuecat.com/docs/projects/configuring-products) and [paywall setup](https://www.revenuecat.com/docs/tools/paywalls).

RevenueCat Test Store product identifiers, durations, and prices cannot be edited after creation. With the owner’s approval, the original unused products were deleted and recreated with the same IDs and the prices above, then reattached to the entitlement and offering. Future price changes require the same deliberate catalog migration.

For App Store release, create the real `monthly` and `yearly` auto-renewable subscriptions in the same subscription group and `lifetime` as a non-consumable in App Store Connect. Connect the app’s real bundle ID to RevenueCat, import those App Store products, attach them to the same entitlement and offering packages, and switch the release key to the Apple public SDK key. The Test Store catalog does not create App Store products. Bitrig’s built-in simulator can exercise the RevenueCat Test Store; real Apple sandbox purchases require a device or TestFlight with a Sandbox Apple Account.

## 4. Check access and handle purchases

`SubscriptionStore` is the source of truth for the UI. It fetches `CustomerInfo` on launch and when the app becomes active, listens to `Purchases.shared.customerInfoStream`, and derives Plus access from the active `lumis_lab_pro` entitlement. It retains the last known customer info if a refresh fails and shows a retry message. Premium content should be shown only while `subscriptions.isPro` is true. Do not save a separate `isPro` flag in `UserDefaults`; that flag could remain true after an expiration or refund.

RevenueCatUI performs purchases on the paywall. `PlusPaywallSheet` listens for completed purchases and restores, updates the store with returned `CustomerInfo`, and replaces the paywall with **Nothing was bought** when a purchase fails. For a custom purchase button, `SubscriptionStore.purchase(_:)` demonstrates `try await Purchases.shared.purchase(package:)`, ignores a user cancellation, and checks the returned entitlement before granting access. `restorePurchases()` provides an explicit restore action, including an informative result when no active Plus purchase is found. The StoreKit/RevenueCat flow handles transaction completion. See [RevenueCat’s purchase guide](https://www.revenuecat.com/docs/getting-started/making-purchases) and [subscription-status guide](https://www.revenuecat.com/docs/getting-started/quickstart#3-check-subscription-status).

## 5. Present the paywall and Customer Center

Launch Angle is the Plus room. Until the family has Plus, its journey stop shows a lemon lock and **Ask a grown-up**. Tapping it opens a kid-safe screen with no prices, then the parental gate: three digits written as words, new digits after every miss, and three misses send the family back. Only after the gate does the app present `PaywallView(offering:displayCloseButton:)` in a SwiftUI sheet, never `presentPaywallIfNeeded`, which would skip the gate. Before showing it, the sheet refreshes customer info, skips the offer for an active Plus customer, and checks that a current offering exists; when the store can’t be reached it shows **Nothing was bought** instead. RevenueCatUI handles the package picker, purchase sheet, and restoration UI, while the app handles the completion and failure callbacks. A purchase or restore that activates `lumis_lab_pro` closes the sheet onto **Launch Angle is unlocked!**; the room itself isn’t built yet, so its stop then reads **Coming soon**. The paywall’s close button returns to Ask a grown-up.

The journey’s **Grown-ups** button goes through the same gate to the grown-ups screen: Plus status, **See plans** (the same paywall) or **Manage subscription**, and **Restore purchases**. See [displaying paywalls](https://www.revenuecat.com/docs/tools/paywalls/displaying-paywalls).

The paywall’s **Terms** and **Privacy** labels are plain text without destinations, as requested for this Test Store prototype. Add reachable Terms of Use and Privacy Policy destinations before App Store release, then republish the paywall. The current Plus benefit copy is a design prototype; verify that every promised room is available before charging real customers.

Customers with an active monthly or yearly Plus subscription see **Manage subscription** on the grown-ups screen. It presents `CustomerCenterView` for plan changes, cancellation help, and restoration. Lifetime purchasers keep access and the restore action, but do not see subscription management. The [Customer Center configuration](https://app.revenuecat.com/projects/c4ecf93e/lifecycle/customer-center) has default support flows and a matching light/dark purple palette. Customer Center is a RevenueCat Pro/Enterprise feature; confirm the project plan and support paths before release. It is never shown on the kid side. See [Customer Center](https://www.revenuecat.com/docs/tools/customer-center) and [the iOS integration guide](https://www.revenuecat.com/docs/tools/customer-center/customer-center-integration-ios).

## 6. Verify the flow

Build the app in Bitrig. On the journey, tap **Launch Angle**, then **I’m a grown-up**, and type the three digits the gate spells out (always 000 in Debug builds). Confirm that all three plans load, then test success, failure, and cancellation with RevenueCat Test Store’s simulated purchase dialog: success shows **Launch Angle is unlocked!** and the stop turns to **Coming soon**, failure shows **Nothing was bought**, and a cancel stays on the paywall. Open **Grown-ups** to confirm **Active** with the plan you chose, and that the matching RevenueCat customer has `lumis_lab_pro`. Test **Restore purchases**, then let a test subscription expire and confirm the lock returns after refresh. Deleting the app starts a new anonymous customer, the quickest way back to the locked state. A Test Store monthly subscription renews on an accelerated schedule; see [Test Store renewal timing](https://www.revenuecat.com/docs/test-and-launch/sandbox/test-store#subscription-renewals-and-expiration).

For production, verify the real bundle ID, App Store product metadata and approvals, the Apple SDK key in Release, the published paywall’s copy and live prices, and the Customer Center configuration. Keep the parental gate on every path to purchase or account management.
