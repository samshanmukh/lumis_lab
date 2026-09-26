import SwiftUI

/// The prediction: two little moon gardens, a gentle ramp and a steep one. Tap one to guess
/// which marble travels farther, then watch both roll.
struct QuizScene: View {
  var model: MarbleQuizModel
  var onSelect: (QuizRamp) -> Void

  var body: some View {
    GeometryReader { geometry in
      let laneHeight = max(84, (geometry.size.height - 34) / 2)
      VStack(spacing: 10) {
        ForEach(QuizRamp.allCases) { choice in
          QuizRampLane(
            choice: choice,
            trial: model.trial(for: choice),
            isSelected: model.selected == choice,
            isFinished: model.finished,
            wentFarther: model.finished && fartherRamp == choice,
            canSelect: model.selected == nil
          ) {
            onSelect(choice)
          }
          .frame(height: laneHeight)
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(LabColor.background.ignoresSafeArea())
    }
  }

  private var fartherRamp: QuizRamp? {
    QuizRamp.allCases.max {
      (model.trial(for: $0)?.stoppingFraction ?? 0) < (model.trial(for: $1)?.stoppingFraction ?? 0)
    }
  }
}

private struct QuizRampLane: View {
  var choice: QuizRamp
  var trial: MarbleTrial?
  var isSelected: Bool
  var isFinished: Bool
  var wentFarther: Bool
  var canSelect: Bool
  var onSelect: () -> Void

  private let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

  var body: some View {
    Button(action: onSelect) {
      TimelineView(.animation(minimumInterval: 1.0 / 60, paused: trial == nil || isFinished)) { timeline in
        Canvas { context, size in
          drawLane(in: &context, size: size, at: timeline.date)
        }
      }
      // The ramps start on the leading side, so the words sit on the trailing side, clear of them.
      .overlay(alignment: .topTrailing) {
        VStack(alignment: .trailing, spacing: 2) {
          Text(choice.title)
            .font(LabFont.label)
            .foregroundStyle(LabColor.primaryInk)
          Text(choice.heightLabel)
            .font(LabFont.caption)
            .foregroundStyle(LabColor.secondaryInk)
          HStack(spacing: 6) {
            if isSelected {
              SceneLabel(text: "your guess", kind: .real)
            }
            if wentFarther {
              SceneLabel(text: "went farther", kind: .goal(met: true))
                .transition(.opacity)
            }
          }
          .padding(.top, 6)
        }
        .multilineTextAlignment(.trailing)
        .padding(15)
        .animation(.easeInOut(duration: 0.2), value: wentFarther)
      }
      .clipShape(shape)
      .overlay {
        shape.strokeBorder(isSelected ? LabColor.label : .white.opacity(0.16), lineWidth: isSelected ? 2 : 1)
      }
      .shadow(color: isSelected ? LabColor.label.opacity(0.25) : .clear, radius: 14)
      .contentShape(shape)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .buttonStyle(LanePressStyle())
    .disabled(!canSelect)
    .accessibilityLabel("\(choice.title), \(choice.heightLabel)")
    .accessibilityValue([isSelected ? "Your guess" : nil, wentFarther ? "Went farther" : nil].compactMap { $0 }.joined(separator: ", "))
    .accessibilityHint(canSelect ? "Choose this ramp and watch both marbles roll" : "Prediction already selected")
  }

  private func drawLane(in context: inout GraphicsContext, size: CGSize, at date: Date) {
    let floor = size.height * 0.79
    let end = CGPoint(x: size.width * 0.38, y: floor)
    let run = min(size.width * 0.32, size.height * 0.60 / tan(choice.angle * .pi / 180))
    let start = CGPoint(x: end.x - run, y: floor - run * tan(choice.angle * .pi / 180))
    let control1 = CGPoint(x: start.x + run * 0.24, y: start.y + (floor - start.y) * 0.24)
    let control2 = CGPoint(x: end.x - run * 0.26, y: floor)
    let radius = min(12, max(8, size.width * 0.017))

    context.fill(
      Path(CGRect(x: 0, y: 0, width: size.width, height: floor)),
      with: .linearGradient(
        Gradient(colors: [LabColor.labelSurface, LabColor.gardenSky, LabColor.gardenHorizon]),
        startPoint: .zero,
        endPoint: CGPoint(x: 0, y: floor)
      )
    )
    for index in 0..<14 {
      let x = CGFloat((index * 137 + 47) % 997) / 997 * size.width
      let y = CGFloat((index * 281 + 79) % 991) / 991 * floor * 0.6
      let diameter: CGFloat = index % 5 == 0 ? 2.6 : 1.6
      context.fill(
        Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
        with: .color(LabColor.secondaryInk.opacity(index % 3 == 0 ? 0.8 : 0.45))
      )
    }

    var hills = Path()
    hills.move(to: CGPoint(x: 0, y: floor))
    hills.addLine(to: CGPoint(x: 0, y: floor - 10))
    hills.addCurve(
      to: CGPoint(x: size.width, y: floor - 12),
      control1: CGPoint(x: size.width * 0.35, y: floor - 26),
      control2: CGPoint(x: size.width * 0.7, y: floor - 2)
    )
    hills.addLine(to: CGPoint(x: size.width, y: floor))
    hills.closeSubpath()
    context.fill(hills, with: .color(LabColor.gardenNearHills))

    context.fill(
      Path(CGRect(x: 0, y: floor, width: size.width, height: size.height - floor)),
      with: .linearGradient(
        Gradient(colors: [LabColor.pathTop, LabColor.pathBottom]),
        startPoint: CGPoint(x: 0, y: floor),
        endPoint: CGPoint(x: 0, y: size.height)
      )
    )
    context.fill(Path(CGRect(x: 0, y: floor - 0.75, width: size.width, height: 1.5)), with: .color(LabColor.pathEdge.opacity(0.5)))

    var ramp = Path()
    ramp.move(to: start)
    ramp.addCurve(to: end, control1: control1, control2: control2)
    context.drawGardenRamp(ramp, top: start, floor: floor, scale: 0.9)

    let motion = trial?.progress(at: date)
    let point: CGPoint
    if let trial, let motion, !motion.onRamp {
      point = CGPoint(
        x: end.x + (trial.stoppingFraction - 0.38) * size.width * motion.distanceFraction,
        y: floor - radius
      )
    } else {
      let t = CGFloat(motion?.distanceFraction ?? 0)
      let inverse = 1 - t
      let x = inverse * inverse * inverse * start.x
        + 3 * inverse * inverse * t * control1.x
        + 3 * inverse * t * t * control2.x
        + t * t * t * end.x
      let y = inverse * inverse * inverse * start.y
        + 3 * inverse * inverse * t * control1.y
        + 3 * inverse * t * t * control2.y
        + t * t * t * end.y
      point = CGPoint(x: x, y: y - radius)
    }

    if isFinished, let trial {
      let stopX = size.width * trial.stoppingFraction
      context.fill(
        Path(ellipseIn: CGRect(x: stopX - 17, y: floor - 4, width: 34, height: 9)),
        with: .color(LabColor.label.opacity(0.32))
      )
    }

    context.drawMarble(at: point, radius: radius, rotation: motion?.rotation ?? 0, glowBlur: 4)
  }
}

/// A lane dips a little when pressed. Once a guess is made the lanes lock without dimming, so
/// both rolls stay easy to watch.
private struct LanePressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
