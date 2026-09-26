import SwiftUI

private enum LabRoute: Equatable {
  case outerWelcome
  case innerWelcome
  case journey
  case door(RoomID)
  case mirror
  case marbleRamp
}

struct LabRootView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var model = AppModel()
  @State private var hinge = HingeModel()
  @State private var mirrorRoom: MirrorRoomModel?
  @State private var marbleRoom: MarbleRampModel?
  @State private var route: LabRoute?
  @State private var returningFromRoom = false

  var body: some View {
    NavigationStack {
      Group {
        switch route {
        case .outerWelcome:
          WelcomeView(isOuter: true) { enterDoor(.mirror) }
            .toolbar(.hidden, for: .navigationBar)
        case .innerWelcome:
          WelcomeView(isOuter: false) { enterDoor(.mirror) }
            .toolbar(.hidden, for: .navigationBar)
        case .journey:
          JourneyView(model: model, lightNewFireflies: returningFromRoom, start: openRoom)
            .toolbar(.hidden, for: .navigationBar)
        case .door(let room):
          DoorView(room: room, hinge: hinge, showsHint: !model.state(room).solved, goToMap: showMap) {
            enterRoom(room)
          }
          .id(room)
          .toolbar(.hidden, for: .navigationBar)
        case .mirror:
          if let mirrorRoom {
            MirrorRoomView(room: mirrorRoom, map: showMap, leave: exitRoom)
          }
        case .marbleRamp:
          if let marbleRoom {
            MarbleRampView(room: marbleRoom, map: showMap, leave: exitRoom)
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

  private func enterDoor(_ room: RoomID) {
    model.markWelcomeSeen()
    model.setStep(.door, room: room)
    withAnimation(LabMotion.room) { route = .door(room) }
  }

  private func enterRoom(_ room: RoomID) {
    model.setStep(.checkpoint1, room: room)
    show(room)
  }

  /// Start resumes the saved step; a finished room replays from its door, keeping its fireflies.
  private func openRoom(_ room: RoomID) {
    returningFromRoom = false
    guard room.isBuilt else { return }
    if model.state(room).solved {
      model.setStep(.door, room: room)
    }
    if model.state(room).step == .door {
      withAnimation(LabMotion.room) { route = .door(room) }
    } else {
      show(room)
    }
  }

  private func show(_ room: RoomID) {
    switch room {
    case .mirror:
      mirrorRoom = MirrorRoomModel(app: model, hinge: hinge)
      withAnimation(LabMotion.room) { route = .mirror }
    case .marbleRamp:
      marbleRoom = MarbleRampModel(app: model, hinge: hinge)
      withAnimation(LabMotion.room) { route = .marbleRamp }
    case .glassPond, .launchAngle:
      break
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
    marbleRoom = nil
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
