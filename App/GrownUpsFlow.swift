import SwiftUI

extension RoomID {
  /// Lumi’s Lab Plus opens Launch Angle; the other rooms are free.
  var needsPlus: Bool { self == .launchAngle }
}

/// The grown-ups side of the journey (Figma 08). Kids only ever see Ask a grown-up and
/// Unlocked; the paywall and the grown-ups settings sit behind the parental gate.
enum GrownUpsRoute: Hashable {
  /// 7.2 · what’s locked and who can open it.
  case askGrownUp(RoomID)
  /// 7.3 · the parental gate.
  case gate(GateTarget)
  /// 7.5 · Plus is open.
  case unlocked(RoomID)
  /// 7.7 · everything a grown-up manages.
  case settings
}

/// What the parental gate opens once it’s passed.
enum GateTarget: Hashable {
  case paywall(RoomID)
  case settings
}

/// A paywall sheet (7.4). `room` is the Plus room a kid asked for, or nil when a grown-up
/// opened the plans from Grown-ups.
struct PaywallRequest: Identifiable {
  let id = UUID()
  var room: RoomID?
}

/// How a paywall sheet ended.
enum PaywallEnding {
  case unlocked
  case notNow
  case closed
}

@MainActor
@Observable
final class GrownUpsFlow {
  var path: [GrownUpsRoute] = []
  var paywall: PaywallRequest?

  /// Starts the grown-ups screens afresh. On the open Duo the journey stays tappable beside
  /// them, so this can replace a grown-ups screen that is already showing.
  func askForPlus(_ room: RoomID) {
    path = [.askGrownUp(room)]
  }

  func openGrownUps() {
    path = [.gate(.settings)]
  }

  func showGate(for room: RoomID) {
    path.append(.gate(.paywall(room)))
  }

  func passGate(_ target: GateTarget) {
    switch target {
    case .paywall(let room): paywall = PaywallRequest(room: room)
    case .settings: path = [.settings]
    }
  }

  /// Cancel, or three wrong codes: back to Ask a grown-up, or to the journey from Grown-ups.
  func leaveGate(_ target: GateTarget) {
    switch target {
    case .paywall: path.removeLast()
    case .settings: path = []
    }
  }

  func seePlans() {
    paywall = PaywallRequest(room: nil)
  }

  /// Moves the navigation under the sheet before it closes, so closing it reveals where the
  /// family goes next. Plans opened from Grown-ups close back to Grown-ups.
  func endPaywall(_ ending: PaywallEnding) {
    if let room = paywall?.room {
      switch ending {
      case .unlocked: path = [.unlocked(room)]
      case .notNow: path = []
      case .closed: leaveGateIfShowing()
      }
    }
    paywall = nil
  }

  /// A swipe down closes the paywall with no callback; it leaves the gate the way Cancel does.
  func paywallDismissed() {
    leaveGateIfShowing()
  }

  func backToJourney() {
    path = []
  }

  private func leaveGateIfShowing() {
    if case .gate = path.last { path.removeLast() }
  }
}

extension View {
  /// The grown-ups screens, pushed on a NavigationStack bound to `flow.path`.
  func grownUpsDestinations(_ flow: GrownUpsFlow) -> some View {
    navigationDestination(for: GrownUpsRoute.self) { route in
      GrownUpsScreen(route: route, flow: flow)
        .toolbar(.hidden, for: .navigationBar)
    }
  }

  /// On the open Duo, the grown-ups screens take the trailing page and this view (the journey)
  /// keeps the leading one, instead of pushing over it. Keep the NavigationStack’s path empty
  /// while `beside` is true.
  func grownUpsBeside(_ flow: GrownUpsFlow, when beside: Bool) -> some View {
    modifier(GrownUpsBeside(flow: flow, beside: beside))
  }

  /// The paywall sheet, presented over the whole stack. Attach it outside the NavigationStack.
  func grownUpsPaywall(_ flow: GrownUpsFlow) -> some View {
    sheet(item: Bindable(flow).paywall, onDismiss: flow.paywallDismissed) { _ in
      PlusPaywallSheet(finish: flow.endPaywall)
    }
  }
}

/// The grown-ups screen for a route, pushed full screen or on the page beside the journey.
private struct GrownUpsScreen: View {
  var route: GrownUpsRoute
  var flow: GrownUpsFlow

  var body: some View {
    switch route {
    case .askGrownUp(let room):
      AskGrownUpView(room: room, grownUp: { flow.showGate(for: room) }, notNow: flow.backToJourney)
    case .gate(let target):
      ParentGateView(pass: { flow.passGate(target) }, leave: { flow.leaveGate(target) })
    case .unlocked(let room):
      PlusUnlockedView(room: room, done: flow.backToJourney)
    case .settings:
      GrownUpsView(seePlans: flow.seePlans, done: flow.backToJourney)
    }
  }
}

/// The journey and the grown-ups page either side of the fold, under one night sky that spans
/// both, so nothing behind the journey moves as the page opens and closes. The page slides in
/// from the trailing edge; its screens cross-fade. While it’s open, VoiceOver reads it first.
private struct GrownUpsBeside: ViewModifier {
  var flow: GrownUpsFlow
  var beside: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    let route = beside ? flow.path.last : nil
    GeometryReader { proxy in
      let fold = FoldSplit.foldX(in: proxy)
      ZStack(alignment: .topLeading) {
        if beside {
          LabBackdrop()
        }
        content
          .environment(\.drawsLabBackdrop, !beside)
          .frame(width: route == nil ? proxy.size.width : fold, height: proxy.size.height)

        if let route {
          ZStack {
            GrownUpsScreen(route: route, flow: flow)
              .id(route)
              .transition(.opacity)
          }
          .environment(\.drawsLabBackdrop, false)
          .frame(width: max(0, proxy.size.width - fold), height: proxy.size.height)
          .overlay(alignment: .leading) {
            Rectangle()
              .fill(.white.opacity(0.08))
              .frame(width: 1)
              .accessibilityHidden(true)
          }
          .offset(x: fold)
          .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
          .accessibilitySortPriority(1)
        }
      }
      .accessibilityElement(children: .contain)
    }
    .animation(reduceMotion ? LabMotion.reduced : .smooth, value: route)
    .onChange(of: route) {
      AccessibilityNotification.ScreenChanged(nil).post()
    }
  }
}
