import SwiftUI

private enum LabRoute {
  case outerWelcome
  case innerWelcome
  case journey
  case door
  case mirror
}

struct LabRootView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var model = AppModel()
  @State private var hinge = HingeModel()
  @State private var mirrorRoom: MirrorRoomModel?
  @State private var route: LabRoute?
  @State private var returningFromRoom = false
  @State private var showingPond = false

  var body: some View {
    NavigationStack {
      Group {
        switch route {
        case .outerWelcome:
          WelcomeView(isOuter: true, action: enterDoor)
            .toolbar(.hidden, for: .navigationBar)
        case .innerWelcome:
          WelcomeView(isOuter: false, action: enterDoor)
            .toolbar(.hidden, for: .navigationBar)
        case .journey:
          JourneyView(model: model, lightNewFireflies: returningFromRoom, start: openMirror) {
            returningFromRoom = false
            showingPond = true
          }
          .toolbar(.hidden, for: .navigationBar)
          .navigationDestination(isPresented: $showingPond) {
            GlassPondView()
          }
        case .door:
          DoorView(hinge: hinge, showsHint: !model.mirror.solved, goToMap: showMap, enterRoom: enterMirror)
            .toolbar(.hidden, for: .navigationBar)
        case .mirror:
          if let mirrorRoom {
            MirrorRoomView(room: mirrorRoom, map: showMap, leave: exitRoom)
          }
        case nil:
          Color.clear
            .toolbar(.hidden, for: .navigationBar)
        }
      }
    }
    .tint(LabColor.retry)
    .onAppear {
      guard route == nil else { return }
      if !model.progress.welcomeSeen {
        route = horizontalSizeClass == .regular ? .innerWelcome : .outerWelcome
      } else {
        route = .journey
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .background { model.save() }
    }
    .hingeInput(hinge)
  }

  private func enterDoor() {
    model.markWelcomeSeen()
    model.setStep(.door)
    withAnimation(LabMotion.room) { route = .door }
  }

  private func enterMirror() {
    model.setStep(.checkpoint1)
    mirrorRoom = MirrorRoomModel(app: model, hinge: hinge)
    withAnimation(LabMotion.step) { route = .mirror }
  }

  /// Start resumes the saved step; a finished room replays from its door, keeping its fireflies.
  private func openMirror() {
    returningFromRoom = false
    if model.mirror.solved {
      model.setStep(.door)
    }
    if model.mirror.step == .door {
      withAnimation(LabMotion.room) { route = .door }
    } else {
      mirrorRoom = MirrorRoomModel(app: model, hinge: hinge)
      withAnimation(LabMotion.room) { route = .mirror }
    }
  }

  private func showMap() {
    returningFromRoom = false
    withAnimation(LabMotion.room) { route = .journey }
  }

  /// roomExit: back to the journey, where the new fireflies light one by one.
  private func exitRoom() {
    returningFromRoom = true
    withAnimation(LabMotion.room) { route = .journey }
    mirrorRoom = nil
  }
}

private extension View {
  @ViewBuilder
  func hingeInput(_ model: HingeModel) -> some View {
    if #available(iOS 27.1, *) {
      onHingeChange { _, newContext in
        model.receive(newContext)
      }
    } else {
      self
    }
  }
}
