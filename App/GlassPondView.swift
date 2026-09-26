import SwiftUI

/// The Glass Pond, played like a laptop: the pond scene on the upright half with the water’s
/// surface on the fold, words and controls on the flat half. Wider than tall, the scene takes the
/// leading half instead. One view tree for every pose; it lays out from its container and the fold.
struct GlassPondView: View {
  var room: GlassPondModel
  var map: () -> Void
  var leave: () -> Void
  /// On to the Marble Ramp from the room’s end; true when its door was tapped there.
  var enterNext: ((Bool) -> Void)? = nil

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var boardAway = false
  @State private var celebrationDone = false
  @State private var bloom = 0.0

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
    .onChange(of: room.hinge.angle) { room.angleChanged() }
    .onChange(of: room.hinge.usesDial) { room.angleChanged() }
    .onChange(of: room.step, initial: true) { _, step in
      if step != .solved { celebrationDone = false }
      if step == .solved {
        withAnimation(reduceMotion ? LabMotion.reduced : .easeOut(duration: 0.8)) { bloom = 1 }
      } else {
        bloom = 0
      }
    }
  }

  private var showsToolbar: Bool {
    !room.step.isCheckpoint && room.step != .roomEnd
  }

  /// Everything is laid out in full-screen coordinates, with the safe area passed in.
  private func content(insets: EdgeInsets) -> some View {
    GeometryReader { proxy in
      let layout = PondLayout(proxy: proxy, insets: insets, laptop: room.hinge.status == .partiallyOpen && room.hinge.deviceAngle != nil, vine: room.showsVine)

      ZStack(alignment: .topLeading) {
        if room.step == .roomEnd {
          RoomEndView(
            finished: GlassPondModel.id,
            app: room.app,
            split: FoldSplit(size: layout.size, insets: insets, foldX: layout.foldX, gap: 40, tallFirstShare: 0.5),
            leave: leave,
            enterNext: enterNext
          )
          .transition(.opacity)
        } else {
          LabBackdrop(showsFireflies: false)
          scene(layout)
          if room.step.isCheckpoint {
            checkpointLayer(layout, insets: insets)
              .transition(.opacity)
          } else {
            stepLayer(layout, insets: insets)
              .transition(.opacity)
          }
          panels(layout)
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
      .animation(reduceMotion ? LabMotion.reduced : .easeInOut(duration: 0.3), value: layout.surfaceY)
    }
    .ignoresSafeArea()
  }

  // MARK: Scene

  private func scene(_ layout: PondLayout) -> some View {
    ZStack(alignment: .topLeading) {
      PondSceneView(tilt: room.sceneTilt, surfaceY: layout.surfaceY, depth: layout.depth, style: sceneStyle(layout), flarePulse: room.flarePulse)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The Glass Pond")
        .accessibilityValue(room.sceneValue)

      Color.clear
        .contentShape(Rectangle())
        .gesture(beatSwipe)
        .allowsHitTesting(room.step == .why)
        .accessibilityHidden(true)
    }
    .frame(width: layout.scene.width, height: layout.scene.height)
    .offset(x: layout.scene.minX, y: layout.scene.minY)
  }

  private func sceneStyle(_ layout: PondLayout) -> PondSceneStyle {
    var style = PondSceneStyle()
    style.mood = room.sceneMood
    style.showsVine = room.showsVine
    style.whyBeat = room.step == .why ? room.whyBeat : nil
    style.bloom = bloom
    style.almost = room.isAlmost
    style.won = room.step == .solved
    style.marksScene = room.hintMarksScene
    style.showsFold = layout.showsFold
    return style
  }

  // MARK: Checkpoints (2.2 and checkpoint 2)

  /// The room’s scene stays still on the upright half; the question board fills the flat half.
  private func checkpointLayer(_ layout: PondLayout, insets: EdgeInsets) -> some View {
    ZStack(alignment: .topLeading) {
      HStack(spacing: 24) {
        MapCapsule(action: map)
        ProgressDots(current: room.step.progressIndex)
      }
      .offset(x: insets.leading + 24, y: insets.top + 20)

      CheckpointBoard(room: room, seeIt: playSeeIt)
        .frame(width: layout.board.width, height: layout.board.height)
        .offset(x: layout.board.minX, y: layout.board.minY + (boardAway ? layout.board.height * 0.25 : 0))
        .opacity(boardAway ? 0 : 1)
    }
  }

  /// seeIt, in place: the board slides away and the scene comes alive where it stands.
  private func playSeeIt() {
    let destination = room.seeItDestination
    guard !reduceMotion else {
      room.go(to: destination)
      return
    }
    withAnimation(.easeIn(duration: 0.3)) { boardAway = true }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(300))
      room.go(to: destination)
      boardAway = false
    }
  }

  // MARK: Scene steps (2.3 to 2.7)

  private func stepLayer(_ layout: PondLayout, insets: EdgeInsets) -> some View {
    ZStack(alignment: .topLeading) {
      ProgressDots(current: room.step.progressIndex)
        .offset(x: layout.wide ? layout.controls.minX : insets.leading + 40, y: insets.top + 24)

      PondStepPanel(room: room, celebrationDone: celebrationDone) { showMath(true) }
        .frame(width: layout.controls.width, height: layout.controls.height, alignment: .topLeading)
        .offset(x: layout.controls.minX, y: layout.controls.minY)

      if room.step == .solved {
        let lily = PondMap(size: layout.scene.size, surfaceY: layout.surfaceY, depth: layout.depth).lilyHeart
        CelebrationFireflies(
          center: CGPoint(x: layout.scene.minX + lily.x, y: layout.scene.minY + lily.y),
          radiusX: 150 * min(1, layout.scene.width / 669),
          settled: Self.aroundTheLily
        ) {
          celebrationDone = true
        }
      }
    }
  }

  /// Fireflies gather above and beside the lily, clear of Lumi at the vine’s other end.
  private static let aroundTheLily: [CGSize] = [
    CGSize(width: -360, height: -120), CGSize(width: -270, height: -190), CGSize(width: -170, height: -220),
    CGSize(width: -70, height: -210), CGSize(width: 0, height: -150), CGSize(width: -430, height: -40)
  ]

  // MARK: Panels

  @ViewBuilder
  private func panels(_ layout: PondLayout) -> some View {
    if room.showingMath {
      MathPanel(sheet: .pond, liveValue: room.liveTilt) { showMath(false) }
        .frame(width: layout.sheet.width, height: layout.sheet.height)
        .offset(x: layout.sheet.minX, y: layout.sheet.minY)
        .transition(reduceMotion ? .opacity : .move(edge: layout.wide ? .trailing : .bottom).combined(with: .opacity))
    }

    if let hint = room.hint, let content = room.hintContent {
      HintPanel(
        content: content,
        state: hint,
        gotIt: { room.closeHint() },
        anotherHint: { room.anotherHint() },
        showMe: { room.showMeFromHint() },
        stop: { room.stopDemo() }
      )
      .frame(width: layout.panel.width, height: layout.panel.height, alignment: layout.wide ? .top : .bottom)
      .offset(x: layout.panel.minX, y: layout.panel.minY)
      .transition(reduceMotion ? .opacity : .move(edge: layout.wide ? .trailing : .bottom).combined(with: .opacity))
    }
  }

  private func showMath(_ show: Bool) {
    if show { room.closeHint() }
    let animation: Animation = reduceMotion ? LabMotion.reduced : (show ? LabMotion.panel : .easeIn(duration: 0.2))
    withAnimation(animation) { room.showingMath = show }
  }

  private var beatSwipe: some Gesture {
    DragGesture(minimumDistance: 24)
      .onEnded { value in
        guard room.step == .why else { return }
        if value.translation.width < -40, room.whyBeat < GlassPondModel.whyBeats - 1 {
          room.nextBeat()
        } else if value.translation.width > 40 {
          room.previousBeat()
        }
      }
  }
}

/// Where the Glass Pond puts things. Open like a laptop, the water’s surface sits on the fold:
/// sky on the upright half, the pond just under the fold, words and controls below it. Taller than
/// wide without a live hinge (open flat, or the outer display), the whole scene fits the upper half
/// and the dial gets the lower half (5.2, 5.3). Wider than tall, the scene takes the leading half.
struct PondLayout {
  var size: CGSize
  var wide: Bool
  var foldX: CGFloat
  /// Where the scene draws; the surface and pond band are in its coordinates.
  var scene: CGRect
  var surfaceY: CGFloat
  var depth: CGFloat
  var controls: CGRect
  var board: CGRect
  /// Hints: under the scene on the flat half, or the trailing half.
  var panel: CGRect
  /// The math sheet: the whole flat half, so the scene stays visible above it.
  var sheet: CGRect
  var showsFold: Bool

  /// `vine` gives the crystal vine, which grows in the air, more sky when the scene is small.
  init(proxy: GeometryProxy, insets: EdgeInsets, laptop: Bool, vine: Bool) {
    size = proxy.size
    wide = size.width > size.height
    let region = proxy.reservedRegions(kind: .division, options: .includeInactive).first
    foldX = region.flatMap { $0.frame.height > $0.frame.width ? $0.frame.midX : nil } ?? size.width / 2

    if wide {
      scene = CGRect(x: 0, y: 0, width: foldX, height: size.height)
      surfaceY = (size.height * 0.6).rounded()
      depth = min(145, size.height * 0.2)
      let leading = foldX + 40
      controls = CGRect(x: leading, y: insets.top + 64, width: max(200, size.width - insets.trailing - 40 - leading), height: max(200, size.height - insets.top - max(40, insets.bottom + 16) - 64))
      board = CGRect(x: foldX + 20, y: insets.top + 24, width: max(200, size.width - insets.trailing - 24 - foldX - 20), height: max(200, size.height - insets.top - insets.bottom - 48))
      panel = CGRect(x: foldX + 24, y: insets.top + 16, width: max(200, size.width - insets.trailing - 16 - foldX - 24), height: max(200, size.height - insets.top - insets.bottom - 32))
      sheet = panel
      showsFold = false
      return
    }

    let foldY = region.flatMap { $0.frame.width > $0.frame.height ? $0.frame.midY : nil }
    let flatTop: CGFloat
    let half: CGFloat
    if laptop, let foldY {
      half = foldY
      surfaceY = foldY
      depth = min(145, max(96, size.height * 0.153))
      flatTop = surfaceY + depth
      showsFold = true
    } else {
      half = (foldY ?? size.height / 2).rounded()
      surfaceY = (half * (vine ? 0.78 : 0.44)).rounded()
      depth = half - surfaceY
      flatTop = half + 24
      showsFold = false
    }
    scene = CGRect(origin: .zero, size: size)
    let leading = insets.leading + 40
    // The system’s vertical toolbar sits on the trailing edge of the flat half.
    let trailing = max(insets.trailing + 16, 104)
    // The primary action sits 40 pt from the bottom edge.
    let bottom = max(40, insets.bottom + 16)
    controls = CGRect(x: leading, y: flatTop + 36, width: max(200, size.width - trailing - leading), height: max(160, size.height - bottom - flatTop - 36))
    board = CGRect(x: insets.leading + 16, y: flatTop + 6, width: size.width - insets.leading - insets.trailing - 32, height: max(200, size.height - 16 - flatTop - 6))
    panel = CGRect(x: insets.leading + 12, y: flatTop + 12, width: size.width - insets.leading - insets.trailing - 24, height: max(200, size.height - max(12, insets.bottom) - flatTop - 12))
    sheet = CGRect(x: insets.leading + 12, y: half + 12, width: size.width - insets.leading - insets.trailing - 24, height: max(200, size.height - max(12, insets.bottom) - half - 12))
  }
}
