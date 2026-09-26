import SwiftUI

/// The Marble Ramp, played like a laptop: the garden on the upright half, the words and controls
/// on the flat half. The room works in any pose; it lays out from its container and the fold.
struct MarbleRampView: View {
  var room: MarbleRampModel
  var map: () -> Void
  var leave: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var celebrationDone = false

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
    .task(id: room.step) { await celebrate() }
  }

  private var showsToolbar: Bool {
    !room.step.isCheckpoint && room.step != .roomEnd
  }

  /// Everything is laid out in full-screen coordinates, with the safe area passed in.
  private func content(insets: EdgeInsets) -> some View {
    GeometryReader { proxy in
      let layout = MarbleLayout(proxy: proxy, insets: insets)
      ZStack(alignment: .topLeading) {
        LinearGradient(colors: [Color(red: 62 / 255, green: 45 / 255, blue: 160 / 255), Color(red: 38 / 255, green: 26 / 255, blue: 109 / 255)], startPoint: .top, endPoint: .bottom)

        if room.step == .roomEnd {
          RoomEndView(
            finished: MarbleRampModel.room,
            fireflies: room.app.fireflies,
            solved: room.app.solvedRooms,
            split: FoldSplit(size: layout.size, insets: insets, foldX: layout.foldX ?? layout.size.width / 2, gap: 40, tallFirstShare: 0.55),
            leave: leave
          )
          .transition(.opacity)
        } else {
          roomLayer(layout: layout, insets: insets)
        }
      }
      .frame(width: layout.size.width, height: layout.size.height)
    }
    .ignoresSafeArea()
  }

  private func roomLayer(layout: MarbleLayout, insets: EdgeInsets) -> some View {
    ZStack(alignment: .topLeading) {
      if layout.isTall {
        LinearGradient(colors: [Color(red: 122 / 255, green: 98 / 255, blue: 224 / 255).opacity(0.16), .clear], startPoint: .top, endPoint: .bottom)
          .frame(width: layout.size.width, height: 160)
          .offset(y: layout.scene.maxY)
      }

      MarbleSceneView(scene: room.scene)
        .place(in: layout.scene)
        .contentShape(Rectangle())
        .gesture(beatSwipe)

      foldGlow(layout)

      chrome(layout: layout, insets: insets)

      if room.step.isCheckpoint {
        CheckpointBoard(
          question: room.checkpointQuestion,
          state: room.checkpoint,
          feedback: room.checkpointFeedback,
          answer: { room.answer($0) },
          forward: { room.checkpointForward() },
          seeIt: { room.seeIt() }
        )
        .place(in: layout.board)
        .transition(reduceMotion ? .opacity : .move(edge: layout.isTall ? .bottom : .trailing).combined(with: .opacity))
      } else {
        MarbleStepPanel(room: room, celebrationDone: celebrationDone) { showMath(true) }
          .place(in: layout.panel)
          .transition(.opacity)
      }

      if room.showingMath {
        MathPanel.marbleRamp(liveAngle: room.rampAngle) { showMath(false) }
          .place(in: layout.sheet)
          .transition(reduceMotion ? .opacity : .move(edge: layout.isTall ? .bottom : .trailing).combined(with: .opacity))
      }

      if let hint = room.hint, let content = room.hintContent {
        HintPanel(
          content: content,
          state: hint,
          gotIt: { room.closeHint() },
          anotherHint: { room.anotherHint() },
          showMe: { room.showMe() },
          stop: { room.stopDemo() }
        )
        .frame(width: layout.hint.width, height: layout.hint.height, alignment: layout.isTall ? .bottom : .top)
        .offset(x: layout.hint.minX, y: layout.hint.minY)
        .transition(reduceMotion ? .opacity : .move(edge: layout.isTall ? .bottom : .trailing).combined(with: .opacity))
      }
    }
  }

  @ViewBuilder
  private func foldGlow(_ layout: MarbleLayout) -> some View {
    if layout.isTall {
      ZStack(alignment: .top) {
        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.04), .white.opacity(0)], startPoint: .top, endPoint: .bottom)
          .frame(height: 44)
          .offset(y: -22)
        Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
      }
      .frame(width: layout.size.width)
      .offset(y: layout.scene.maxY)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    } else {
      Rectangle()
        .fill(.white.opacity(0.08))
        .frame(width: 1, height: layout.size.height)
        .offset(x: layout.scene.maxX)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
  }

  /// Top leading over the garden: Map and progress on checkpoints, progress on the other steps.
  private func chrome(layout: MarbleLayout, insets: EdgeInsets) -> some View {
    HStack(spacing: 24) {
      if room.step.isCheckpoint {
        MapCapsule(action: map)
      }
      ProgressDots(current: room.step.progressIndex)
    }
    .offset(x: insets.leading + (room.step.isCheckpoint ? 24 : 40), y: insets.top + (room.step.isCheckpoint ? 20 : 32))
  }

  private var beatSwipe: some Gesture {
    DragGesture(minimumDistance: 24)
      .onEnded { value in
        guard room.step == .why else { return }
        if value.translation.width < -40, room.whyBeat < MarbleRampModel.whyBeats - 1 {
          room.nextBeat()
        } else if value.translation.width > 40 {
          room.previousBeat()
        }
      }
  }

  private func showMath(_ show: Bool) {
    if show { room.closeHint() }
    let animation: Animation = reduceMotion ? LabMotion.reduced : (show ? LabMotion.panel : .easeIn(duration: 0.2))
    withAnimation(animation) { room.showingMath = show }
  }

  /// celebrate (1.6 s), then the forward button rises in.
  private func celebrate() async {
    guard room.step == .solved else {
      celebrationDone = false
      return
    }
    try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 1600))
    guard !Task.isCancelled else { return }
    celebrationDone = true
  }
}

/// Where the garden and the controls go. Laptop pose (taller than wide) puts the garden above
/// the fold; book pose or a wide screen puts it on the leading half.
private struct MarbleLayout {
  var size: CGSize
  var isTall: Bool
  var foldX: CGFloat?
  var scene: CGRect
  var panel: CGRect
  var board: CGRect
  var sheet: CGRect
  var hint: CGRect

  init(proxy: GeometryProxy, insets: EdgeInsets) {
    size = proxy.size
    isTall = size.height >= size.width
    let regions = proxy.reservedRegions(kind: .division, options: .includeInactive)
    let horizontalFold = regions.first { $0.frame.width > $0.frame.height }?.frame.midY
    let verticalFold = regions.first { $0.frame.height > $0.frame.width }?.frame.midX

    if isTall {
      foldX = nil
      let sceneHeight = horizontalFold ?? min(size.height * 0.5, size.width * MarbleGarden.size.height / MarbleGarden.size.width + insets.top)
      scene = CGRect(x: 0, y: 0, width: size.width, height: sceneHeight)
      let leading = insets.leading + 40
      let width = size.width - leading - insets.trailing - 32
      panel = CGRect(x: leading, y: sceneHeight + (horizontalFold == nil ? 28 : 64), width: width, height: size.height - sceneHeight - (horizontalFold == nil ? 28 : 64) - insets.bottom - 40)
      board = CGRect(x: insets.leading + 16, y: sceneHeight + 16, width: size.width - insets.leading - insets.trailing - 32, height: size.height - sceneHeight - 32 - insets.bottom)
      let sheetHeight = min(size.height * 0.62, 560)
      sheet = CGRect(x: insets.leading + 12, y: size.height - insets.bottom - 12 - sheetHeight, width: size.width - insets.leading - insets.trailing - 24, height: sheetHeight)
      hint = CGRect(x: insets.leading + 12, y: sceneHeight + 12, width: size.width - insets.leading - insets.trailing - 24, height: size.height - sceneHeight - 24 - insets.bottom)
    } else {
      let fold = verticalFold ?? size.width / 2
      foldX = verticalFold
      scene = CGRect(x: 0, y: 0, width: fold, height: size.height)
      let leading = fold + 40
      let width = size.width - leading - insets.trailing - 32
      panel = CGRect(x: leading, y: insets.top + 40, width: width, height: size.height - insets.top - insets.bottom - 80)
      board = CGRect(x: fold + 20, y: insets.top + 24, width: size.width - fold - 20 - insets.trailing - 24, height: size.height - insets.top - insets.bottom - 48)
      sheet = CGRect(x: fold + 24, y: insets.top + 16, width: size.width - fold - 24 - insets.trailing - 16, height: size.height - insets.top - insets.bottom - 32)
      hint = CGRect(x: fold + 24, y: insets.top + 16, width: min(440, size.width - fold - 24 - insets.trailing - 16), height: size.height * 0.6)
    }
  }
}
