import SwiftUI

/// The forward step for each scene step, 40 pt from the bottom. A primary button is
/// either shown or not shown, never disabled.
struct MirrorStepActions: View {
  var room: MirrorRoomModel
  var celebrationDone: Bool
  var showMath: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 12) {
      switch room.step {
      case .tryIt:
        if room.heldAtGoal {
          PrimaryLabButton(title: "Count", fillsWidth: false) { room.countThem() }
            .transition(rise)
        }
        QuietLabButton(title: "Show me 90°") { room.showMeGoal() }
          .padding(.leading, room.heldAtGoal ? 0 : -8)
      case .check:
        if room.countOutcome == .right || room.countOutcome == .revealed {
          PrimaryLabButton(title: "Why 4?", fillsWidth: false) { room.startWhy() }
            .transition(rise)
        }
      case .why:
        PrimaryLabButton(title: "Next", fillsWidth: false) { room.nextBeat() }
        if room.whyBeat == 2 {
          QuietLabButton(title: "Show the math", systemImage: "sum", action: showMath)
            .transition(.opacity)
        }
      case .solved:
        if celebrationDone {
          PrimaryLabButton(title: "Next: The Glass Pond", fillsWidth: false) { room.finishRoom() }
            .transition(rise)
        }
      default:
        EmptyView()
      }
    }
    .animation(reduceMotion ? LabMotion.reduced : LabMotion.step, value: room.heldAtGoal)
    .animation(reduceMotion ? LabMotion.reduced : LabMotion.step, value: room.countOutcome)
    .animation(reduceMotion ? LabMotion.reduced : LabMotion.step, value: celebrationDone)
  }

  private var rise: AnyTransition {
    reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12))
  }
}
