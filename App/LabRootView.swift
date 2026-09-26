import SwiftUI

private enum LabRoute {
  case outerWelcome
  case innerWelcome
  case journey
  case door
  case mirror
  case marble
}

struct LabRootView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var model = AppModel()
  @State private var hinge = HingeModel()
  @State private var route: LabRoute?

  var body: some View {
    NavigationStack {
      Group {
        switch route {
        case .outerWelcome:
          WelcomeView(isOuter: true, action: enterDoor)
        case .innerWelcome:
          WelcomeView(isOuter: false, action: enterDoor)
        case .journey:
          JourneyView(model: model, start: resumeMirror, startMarble: enterMarble)
        case .door:
          DoorView(hinge: hinge, goToMap: showMap, enterRoom: enterMirror)
        case .mirror:
          PlaceholderRoomView(hinge: hinge, map: showMap)
        case .marble:
          ContentView(onExitToMap: showMap, onCompleted: completeMarble)
        case nil:
          Color.clear
        }
      }
      .toolbar(.hidden, for: .navigationBar)
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
    withAnimation(LabMotion.step) { route = .mirror }
  }

  private func resumeMirror() {
    withAnimation(LabMotion.room) {
      route = model.mirror.step == .door ? .door : .mirror
    }
  }

  private func enterMarble() {
    model.setStep(.door, room: .marbleRamp)
    withAnimation(LabMotion.room) { route = .marble }
  }

  private func completeMarble() {
    model.updateRoom(.marbleRamp) { state in
      state.step = .solved
      state.solved = true
      state.fireflies.insert(.challenge)
    }
  }

  private func showMap() {
    withAnimation(LabMotion.room) { route = .journey }
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
