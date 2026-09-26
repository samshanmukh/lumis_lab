import SwiftUI

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
            canSelect: model.selected == nil
          ) {
            onSelect(choice)
          }
          .frame(height: laneHeight)
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        LinearGradient(
          colors: [Color(red: 0.20, green: 0.18, blue: 0.53), Color(red: 0.12, green: 0.10, blue: 0.37)],
          startPoint: .top,
          endPoint: .bottom
        )
      )
    }
  }
}

private struct QuizRampLane: View {
  var choice: QuizRamp
  var trial: MarbleTrial?
  var isSelected: Bool
  var isFinished: Bool
  var canSelect: Bool
  var onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      TimelineView(.animation(minimumInterval: 1.0 / 60, paused: trial == nil || isFinished)) { timeline in
        Canvas { context, size in
          drawLane(in: context, size: size, at: timeline.date)
        }
      }
      .overlay(alignment: .topLeading) {
        VStack(alignment: .leading, spacing: 2) {
          Text(choice.title)
            .font(.system(.headline, design: .rounded, weight: .bold))
          Text(choice.heightLabel)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.white.opacity(0.66))
        }
        .padding(15)
      }
      .background(
        LinearGradient(
          colors: [Color(red: 0.30, green: 0.26, blue: 0.67), Color(red: 0.20, green: 0.17, blue: 0.49)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .clipShape(RoundedRectangle(cornerRadius: 21))
      .overlay {
        RoundedRectangle(cornerRadius: 21)
          .strokeBorder(isSelected ? Color(red: 1, green: 0.86, blue: 0.59) : .white.opacity(0.22), lineWidth: isSelected ? 2.5 : 1)
      }
      .contentShape(RoundedRectangle(cornerRadius: 21))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .buttonStyle(.plain)
    .disabled(!canSelect)
    .accessibilityLabel("\(choice.title), \(choice.heightLabel)")
    .accessibilityHint(canSelect ? "Choose this ramp and watch both marbles roll" : "Prediction already selected")
  }

  private func drawLane(in context: GraphicsContext, size: CGSize, at date: Date) {
    let floor = size.height * 0.79
    let end = CGPoint(x: size.width * 0.38, y: floor)
    let run = min(size.width * 0.32, size.height * 0.60 / tan(choice.angle * .pi / 180))
    let start = CGPoint(x: end.x - run, y: floor - run * tan(choice.angle * .pi / 180))
    let control1 = CGPoint(x: start.x + run * 0.24, y: start.y + (floor - start.y) * 0.24)
    let control2 = CGPoint(x: end.x - run * 0.26, y: floor)
    let radius = min(12, max(8, size.width * 0.017))

    var ground = Path()
    ground.move(to: CGPoint(x: 0, y: floor))
    ground.addLine(to: CGPoint(x: size.width, y: floor))
    context.stroke(ground, with: .color(.white.opacity(0.43)), lineWidth: 1.5)

    var support = Path()
    support.move(to: start)
    support.addLine(to: CGPoint(x: start.x, y: floor))
    context.stroke(support, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))

    var ramp = Path()
    ramp.move(to: start)
    ramp.addCurve(to: end, control1: control1, control2: control2)
    context.stroke(ramp, with: .color(Color(red: 0.73, green: 0.62, blue: 1).opacity(0.45)), style: StrokeStyle(lineWidth: 11, lineCap: .round))
    context.stroke(ramp, with: .color(Color(red: 0.97, green: 0.93, blue: 1)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

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
        with: .color(Color(red: 1, green: 0.82, blue: 0.55).opacity(0.32))
      )
    }

    var ball = context
    ball.translateBy(x: point.x, y: point.y)
    ball.rotate(by: .radians(motion?.rotation ?? 0))
    let circle = Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
    ball.fill(
      circle,
      with: .radialGradient(
        Gradient(colors: [Color(red: 1, green: 0.98, blue: 0.88), Color(red: 1, green: 0.74, blue: 0.38), Color(red: 0.75, green: 0.39, blue: 0.29)]),
        center: CGPoint(x: -radius * 0.35, y: -radius * 0.4),
        startRadius: 1,
        endRadius: radius * 1.8
      )
    )
    ball.stroke(circle, with: .color(.white.opacity(0.75)), lineWidth: 1)
    ball.fill(Path(ellipseIn: CGRect(x: -radius * 0.5, y: -radius * 0.6, width: radius * 0.35, height: radius * 0.35)), with: .color(.white.opacity(0.9)))
  }
}
