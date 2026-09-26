import SwiftUI

private enum LabRoute: Equatable {
  case outerWelcome
  case innerWelcome
  case journey
  case door(RoomID)
  case room(RoomID)
}

struct LabRootView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var model = AppModel()
  @State private var hinge = HingeModel()
  @State private var mirrorRoom: MirrorRoomModel?
  @State private var pondRoom: GlassPondModel?
  @State private var route: LabRoute?
  @State private var justFinished: RoomID?
  @State private var doorOpensAtOnce = false
  @State private var grownUps = GrownUpsFlow()

  var body: some View {
    NavigationStack(path: $grownUps.path) {
      Group {
        switch route {
        case .outerWelcome:
          WelcomeView(isOuter: true, action: enterDoor)
            .toolbar(.hidden, for: .navigationBar)
        case .innerWelcome:
          WelcomeView(isOuter: false, action: enterDoor)
            .toolbar(.hidden, for: .navigationBar)
        case .journey:
          JourneyView(
            model: model,
            justFinished: justFinished,
            start: openRoom,
            askGrownUp: grownUps.askForPlus,
            openGrownUps: grownUps.openGrownUps
          )
          .toolbar(.hidden, for: .navigationBar)
        case .door(let room):
          DoorView(
            room: room,
            hinge: hinge,
            showsHint: !model.room(room).solved,
            opensAtOnce: doorOpensAtOnce,
            goToMap: showMap,
            enterRoom: { enter(room) }
          )
          .id(room)
          .toolbar(.hidden, for: .navigationBar)
        case .room(.mirror):
          if let mirrorRoom {
            MirrorRoomView(room: mirrorRoom, map: showMap, leave: exitRoom) { tapped in
              goToDoor(.glassPond, opensAtOnce: tapped)
            }
          }
        case .room(.glassPond):
          if let pondRoom {
            GlassPondView(room: pondRoom, map: showMap, leave: exitRoom) { _ in openMarble() }
          }
        case .room(.marbleRamp):
          MarbleChapterView(onExitToMap: showMap, onCompleted: completeMarble)
            .toolbar(.hidden, for: .navigationBar)
        case .room, nil:
          Color.clear
            .toolbar(.hidden, for: .navigationBar)
        }
      }
      .grownUpsDestinations(grownUps)
    }
    .grownUpsPaywall(grownUps)
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
    model.setStep(.door, room: .mirror)
    withAnimation(LabMotion.room) { route = .door(.mirror) }
  }

  private func enter(_ room: RoomID) {
    model.setStep(.checkpoint1, room: room)
    makeModel(for: room)
    doorOpensAtOnce = false
    withAnimation(LabMotion.step) { route = .room(room) }
  }

  private func makeModel(for room: RoomID) {
    switch room {
    case .mirror: mirrorRoom = MirrorRoomModel(app: model, hinge: hinge)
    case .glassPond: pondRoom = GlassPondModel(app: model, hinge: hinge)
    case .marbleRamp, .launchAngle: break
    }
  }

  /// Start resumes the saved step; a finished room replays from its door, keeping its fireflies.
  private func openRoom(_ room: RoomID) {
    guard room.isPlayable else { return }
    if room == .marbleRamp {
      openMarble()
      return
    }
    justFinished = nil
    doorOpensAtOnce = false
    if model.room(room).solved {
      model.setStep(.door, room: room)
    }
    if model.room(room).step == .door {
      withAnimation(LabMotion.room) { route = .door(room) }
    } else {
      makeModel(for: room)
      withAnimation(LabMotion.room) { route = .room(room) }
    }
  }

  /// From a room’s end straight to the next room’s door; a tap there opens it by itself.
  private func goToDoor(_ room: RoomID, opensAtOnce: Bool) {
    model.setStep(.door, room: room)
    justFinished = nil
    doorOpensAtOnce = opensAtOnce
    withAnimation(LabMotion.room) { route = .door(room) }
    mirrorRoom = nil
    pondRoom = nil
  }

  /// The Marble Ramp is its own chapter with its own door; it always starts there.
  private func openMarble() {
    justFinished = nil
    model.setStep(.door, room: .marbleRamp)
    withAnimation(LabMotion.room) { route = .room(.marbleRamp) }
    mirrorRoom = nil
    pondRoom = nil
  }

  private func completeMarble() {
    model.updateRoom(.marbleRamp) { state in
      state.step = .solved
      state.solved = true
      state.fireflies.insert(.challenge)
    }
  }

  private func showMap() {
    justFinished = nil
    withAnimation(LabMotion.room) { route = .journey }
  }

  /// roomExit: back to the journey, where the finished room’s fireflies light one by one.
  private func exitRoom() {
    if case .room(let room) = route { justFinished = room }
    withAnimation(LabMotion.room) { route = .journey }
    mirrorRoom = nil
    pondRoom = nil
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
