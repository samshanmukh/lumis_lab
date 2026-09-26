import SwiftUI

/// The Mirror Room, played in book pose: the phone’s two halves are the two mirrors.
/// One view tree for every pose; it lays out from its container and the fold.
struct MirrorRoomView: View {
  var room: MirrorRoomModel
  var map: () -> Void
  var leave: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var sceneSlot: CGRect = .zero
  @State private var seeIt = SeeItPlayback()
  @State private var foldGlow = 0.0
  @State private var celebrationDone = false
  @State private var sliceReveal = 0

  private let space = "mirrorRoom"

  var body: some View {
    GeometryReader { safeArea in
      content(insets: safeArea.safeAreaInsets)
    }
    .toolbar {
      if showsToolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Map", systemImage: "chevron.left", action: map)
        }
        if room.hintContent != nil {
          ToolbarItem(placement: .primaryAction) {
            Button("Hint", systemImage: room.hint == nil ? "lightbulb" : "lightbulb.fill") {
              room.toggleHint()
            }
          }
        }
      }
    }
    .toolbar(showsToolbar ? .visible : .hidden, for: .navigationBar)
    .toolbarBackground(.hidden, for: .navigationBar)
    .sensoryFeedback(.success, trigger: room.successTick)
    .sensoryFeedback(.impact(flexibility: .soft), trigger: room.softTick)
    .sensoryFeedback(.selection, trigger: room.selectionTick)
    .onChange(of: room.hinge.mirrorAngle) { room.angleChanged() }
    .onChange(of: room.hinge.usesDial) { room.angleChanged() }
    .onChange(of: room.step) { _, step in
      if step != .solved { celebrationDone = false }
    }
    .task(id: room.whyBeat) { await revealSlices() }
  }

  /// Everything is laid out in full-screen coordinates, with the safe area passed in.
  private func content(insets: EdgeInsets) -> some View {
    GeometryReader { proxy in
      let size = proxy.size
      let foldX = FoldSplit.foldX(in: proxy)
      let wide = size.width > size.height
      let scene = sceneGeometry(size: size, insets: insets, foldX: foldX, wide: wide)

      ZStack(alignment: .topLeading) {
        if room.step.isCheckpoint {
          checkpointLayer(size: size, insets: insets, foldX: foldX, wide: wide)
            .transition(.opacity)
        } else if room.step == .roomEnd {
          RoomEndView(
            finished: .mirror,
            fireflies: room.app.fireflies,
            solved: room.app.solvedRooms,
            split: FoldSplit(size: size, insets: insets, foldX: foldX, gap: 40, tallFirstShare: 0.55),
            leave: leave
          )
            .transition(.opacity)
        } else {
          sceneLayer(size: size, insets: insets, foldX: foldX, wide: wide, scene: scene)
            .transition(.opacity)
        }

        if seeIt.active {
          SeeItOverlay(from: seeIt.from, size: size, foldX: foldX, progress: seeIt.progress, glass: seeIt.glass)
        }
      }
      .frame(width: size.width, height: size.height)
      .coordinateSpace(.named(space))
      .allowsHitTesting(!seeIt.active)
    }
    .ignoresSafeArea()
  }

  private var showsToolbar: Bool {
    !room.step.isCheckpoint && room.step != .roomEnd
  }

  // MARK: Checkpoints (1.2 and Checkpoint 2)

  private func checkpointLayer(size: CGSize, insets: EdgeInsets, foldX: CGFloat, wide: Bool) -> some View {
    let split = FoldSplit(size: size, insets: insets, foldX: foldX)
    let art = wide
      ? CGRect(x: 0, y: 0, width: foldX, height: size.height)
      : CGRect(x: 0, y: 0, width: size.width, height: split.first.maxY)
    let boardInsets = wide
      ? EdgeInsets(top: 24, leading: 0, bottom: 24, trailing: 24)
      : EdgeInsets(top: 4, leading: 16, bottom: 16, trailing: 16)

    return ZStack(alignment: .topLeading) {
      MirrorRoomInterior(roomFrame: art, showsMirrors: !seeIt.active)
        .opacity(seeIt.active ? 1 - 0.7 * seeIt.progress : 1)

      HStack(spacing: 24) {
        MapCapsule(action: map)
        ProgressDots(current: room.step.progressIndex)
      }
      .offset(x: split.first.minX + 24, y: split.first.minY + 20)

      CheckpointBoard(
        question: room.checkpointQuestion,
        state: room.checkpoint,
        feedback: room.checkpointFeedback,
        answer: { room.answer($0) },
        forward: { room.checkpointForward() },
        seeIt: { playSeeIt(art: art) }
      )
        .padding(boardInsets)
        .place(in: split.second)
        .offset(x: seeIt.boardAway ? size.width * 0.55 : 0)
        .opacity(seeIt.boardAway ? 0 : 1)
    }
  }

  // MARK: Scene steps (1.3 to 1.7)

  private func sceneLayer(size: CGSize, insets: EdgeInsets, foldX: CGFloat, wide: Bool, scene: SceneGeometry) -> some View {
    ZStack(alignment: .topLeading) {
      MirrorHallBackdrop(center: scene.center, radiusX: scene.radiusX, foldX: wide ? foldX : nil, foldGlow: foldGlow)
        .contentShape(Rectangle())
        .gesture(beatSwipe)

      MirrorSceneView(angle: room.sceneAngle, center: scene.center, radiusX: scene.radiusX, style: sceneStyle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mirrors")
        .accessibilityValue("\(room.sceneCount) Lumis in the circle")

      if room.step == .solved {
        CelebrationFireflies(center: scene.center, radiusX: scene.radiusX) {
          celebrationDone = true
        }
      }

      if wide {
        wideControls(size: size, insets: insets, foldX: foldX)
      } else {
        tallControls(size: size, insets: insets)
      }

      if room.showingMath {
        mathPanel(size: size, insets: insets, foldX: foldX, wide: wide)
      }

      if let hint = room.hint, let content = room.hintContent {
        hintPanel(hint, content: content, size: size, insets: insets, foldX: foldX, wide: wide)
      }
    }
  }

  private func wideControls(size: CGSize, insets: EdgeInsets, foldX: CGFloat) -> some View {
    let leading = insets.leading + 40
    let headerWidth = min(440, max(260, foldX - 40 - leading))
    return ZStack(alignment: .topLeading) {
      MirrorStepPanel(room: room)
        .frame(width: headerWidth, alignment: .leading)
        .padding(.leading, leading)
        .padding(.top, insets.top + 36)

      AngleReadout(angle: room.sceneAngle, goal: room.step == .tryIt ? MirrorRoomModel.tryItGoal : nil, goalMet: room.heldAtGoal)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, insets.trailing + 40)
        .padding(.top, insets.top + 24)

      MirrorStepActions(room: room, celebrationDone: celebrationDone) { showMath(true) }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.leading, leading)
        .padding(.bottom, insets.bottom + 40)

      if showsDial {
        AngleDial(hinge: room.hinge)
          .disabled(room.isDemoPlaying)
          .opacity(room.isDemoPlaying ? 0.45 : 1)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
          .padding(.trailing, insets.trailing + 40)
          .padding(.bottom, insets.bottom + 40)
          .transition(.opacity)
      }
    }
    .frame(width: size.width, height: size.height, alignment: .topLeading)
  }

  private func tallControls(size: CGSize, insets: EdgeInsets) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      MirrorStepPanel(room: room)

      Color.clear
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(space)) } action: { sceneSlot = $0 }
        .overlay(alignment: .topTrailing) {
          if !showsDial {
            AngleReadout(angle: room.sceneAngle, goal: room.step == .tryIt ? MirrorRoomModel.tryItGoal : nil, goalMet: room.heldAtGoal)
          }
        }

      if showsDial {
        VStack(spacing: 8) {
          AngleDial(hinge: room.hinge)
            .disabled(room.isDemoPlaying)
            .opacity(room.isDemoPlaying ? 0.45 : 1)
          Text("Drag to fold")
            .font(LabFont.caption)
            .foregroundStyle(LabColor.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24)
      }

      MirrorStepActions(room: room, celebrationDone: celebrationDone) { showMath(true) }
    }
    .padding(.leading, insets.leading + 32)
    .padding(.trailing, insets.trailing + 24)
    .padding(.top, insets.top + 28)
    .padding(.bottom, insets.bottom + 32)
    .frame(width: size.width, height: size.height)
  }

  private var showsDial: Bool {
    room.isLive && room.hinge.usesDial
  }

  private func mathPanel(size: CGSize, insets: EdgeInsets, foldX: CGFloat, wide: Bool) -> some View {
    let frame: CGRect
    if wide {
      let minX = foldX + 24
      frame = CGRect(x: minX, y: insets.top + 16, width: size.width - insets.trailing - 16 - minX, height: size.height - insets.top - insets.bottom - 32)
    } else {
      let height = size.height * 0.62
      frame = CGRect(x: insets.leading + 12, y: size.height - insets.bottom - 12 - height, width: size.width - insets.leading - insets.trailing - 24, height: height)
    }
    return MathPanel.mirror(liveAngle: room.hinge.mirrorAngle) { showMath(false) }
      .frame(width: frame.width, height: frame.height)
      .offset(x: frame.minX, y: frame.minY)
      .transition(reduceMotion ? .opacity : .move(edge: wide ? .trailing : .bottom).combined(with: .opacity))
  }

  private func showMath(_ show: Bool) {
    if show { room.closeHint() }
    let animation: Animation = reduceMotion ? LabMotion.reduced : (show ? LabMotion.panel : .easeIn(duration: 0.2))
    withAnimation(animation) { room.showingMath = show }
  }

  /// The hint sits on the trailing half under the readout when the phone is open like a book,
  /// and across the top on a narrow screen, so the scene and the dial stay usable.
  private func hintPanel(_ hint: HintState, content: HintContent, size: CGSize, insets: EdgeInsets, foldX: CGFloat, wide: Bool) -> some View {
    let frame: CGRect
    if wide {
      let minX = foldX + 24
      frame = CGRect(x: minX, y: insets.top + 168, width: min(440, size.width - insets.trailing - 16 - minX), height: size.height * 0.5)
    } else {
      frame = CGRect(x: insets.leading + 12, y: insets.top + 12, width: size.width - insets.leading - insets.trailing - 24, height: size.height * 0.5)
    }
    return HintPanel(
      content: content,
      state: hint,
      gotIt: { room.closeHint() },
      anotherHint: { room.anotherHint() },
      showMe: { room.showMe() },
      stop: { room.stopDemo() }
    )
    .frame(width: frame.width, height: frame.height, alignment: .top)
    .offset(x: frame.minX, y: frame.minY)
    .transition(reduceMotion ? .opacity : .move(edge: wide ? .trailing : .top).combined(with: .opacity))
  }

  private var beatSwipe: some Gesture {
    DragGesture(minimumDistance: 24)
      .onEnded { value in
        guard room.step == .why else { return }
        if value.translation.width < -40, room.whyBeat < MirrorRoomModel.whyBeats - 1 {
          room.nextBeat()
        } else if value.translation.width > 40 {
          room.previousBeat()
        }
      }
  }

  private var sceneStyle: MirrorSceneStyle {
    var style = MirrorSceneStyle()
    style.mood = room.sceneMood
    style.showsTarget = room.step == .tryIt
    style.targetAngle = MirrorRoomModel.tryItGoal
    style.labelsReflections = room.step == .check && (room.countOutcome == .right || room.countOutcome == .revealed)
    style.whyBeat = room.step == .why ? room.whyBeat : nil
    style.showsSliceEdges = room.step != .why || (room.whyBeat == 2 && sliceReveal > 0)
    style.floorWarm = room.step == .tryIt && room.heldAtGoal
    style.pulsingLumi = room.pulsingLumi
    style.floorPulse = room.floorPulse
    style.sliceReveal = sliceReveal
    return style
  }

  /// Beat c draws the slices and their numbers in one by one.
  private func revealSlices() async {
    guard room.step == .why, room.whyBeat == 2 else {
      sliceReveal = 0
      return
    }
    let count = MirrorOptics.count(for: MirrorRoomModel.tryItGoal)
    if reduceMotion {
      withAnimation(LabMotion.reduced) { sliceReveal = count }
      return
    }
    for index in 1...count {
      try? await Task.sleep(for: .milliseconds(300))
      guard !Task.isCancelled else { return }
      withAnimation(.easeOut(duration: 0.3)) { sliceReveal = index }
    }
  }

  // MARK: See it

  private func playSeeIt(art: CGRect) {
    let destination = room.seeItDestination
    guard !reduceMotion, art.width > 0 else {
      withAnimation(.easeInOut(duration: 0.25)) { foldGlow = 1 }
      room.go(to: destination)
      withAnimation(.easeOut(duration: 0.6).delay(0.25)) { foldGlow = 0 }
      return
    }

    seeIt = SeeItPlayback(active: true, from: RoomArt(frame: art).mirrorQuads)
    withAnimation(.easeIn(duration: 0.25)) { seeIt.boardAway = true }
    withAnimation(.spring(duration: 0.6, bounce: 0.08).delay(0.1)) { seeIt.progress = 1 }

    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(650))
      withAnimation(.easeInOut(duration: 0.25)) { foldGlow = 1 }
      room.go(to: destination)
      withAnimation(.easeOut(duration: 0.4)) { seeIt.glass = 0 }
      try? await Task.sleep(for: .milliseconds(450))
      seeIt = SeeItPlayback()
      withAnimation(.easeOut(duration: 0.8)) { foldGlow = 0 }
    }
  }

  // MARK: Layout

  private func sceneGeometry(size: CGSize, insets: EdgeInsets, foldX: CGFloat, wide: Bool) -> SceneGeometry {
    if wide {
      return SceneGeometry(
        center: CGPoint(x: foldX, y: size.height * 0.7),
        radiusX: min(size.width * 0.315, size.height * 0.45)
      )
    }
    let slot = sceneSlot.height > 40
      ? sceneSlot
      : CGRect(x: insets.leading, y: size.height * 0.3, width: size.width - insets.leading - insets.trailing, height: size.height * 0.4)
    return SceneGeometry(
      center: CGPoint(x: slot.midX, y: slot.minY + slot.height * 0.64),
      radiusX: min(slot.width * 0.42, slot.height * 0.95)
    )
  }
}

private struct SceneGeometry {
  var center: CGPoint
  var radiusX: CGFloat
}

private struct SeeItPlayback {
  var active = false
  var from: (left: [CGPoint], right: [CGPoint]) = ([], [])
  var progress: CGFloat = 0
  var glass = 1.0
  var boardAway = false
}
