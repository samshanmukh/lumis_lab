import SwiftUI

/// 7.3 · Keeps purchases and settings behind a grown-up. The three digits are written as
/// words, so a pre-reader can’t copy them, and they change after every miss. The third right
/// digit opens the way; three wrong codes send the family back.
struct ParentGateView: View {
  var pass: () -> Void
  var leave: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var challenge = GateChallenge.make()
  @State private var entry: [Int] = []
  @State private var missed = false
  @State private var wrongTries = 0
  @State private var shakes = 0
  @State private var passed = false

  var body: some View {
    GrownUpsPage { split in
      if split.isSideBySide {
        VStack(alignment: .leading, spacing: 0) {
          header
          entryDots.padding(.top, 48)
          Spacer(minLength: 24)
          QuietLabButton(title: "Cancel", action: leave)
        }
        .place(in: split.first)
        keypad(KeypadLayout())
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .place(in: split.second)
      } else {
        let layout = KeypadLayout(height: split.column.height)
        VStack(alignment: .leading, spacing: 0) {
          header
          entryDots.padding(.top, layout.entryGap)
          keypad(layout)
            .frame(maxWidth: .infinity)
            .padding(.top, layout.keypadGap)
          Spacer(minLength: 0)
          if !layout.cancelInKeypad {
            QuietLabButton(title: "Cancel", action: leave)
              .padding(.top, 24)
          }
        }
        .place(in: split.column)
      }
    }
    .sensoryFeedback(.impact(flexibility: .soft), trigger: wrongTries)
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("For grown-ups")
        .font(LabFont.display)
        .foregroundStyle(LabColor.primaryInk)
        .accessibilityAddTraits(.isHeader)
      Text(challenge.prompt)
        .font(LabFont.body)
        .foregroundStyle(LabColor.secondaryInk)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  /// Entered digits as dots: lemon as they’re typed, lavender for a code that didn’t match.
  private var entryDots: some View {
    VStack(spacing: 20) {
      HStack(spacing: 18) {
        ForEach(0..<GateChallenge.length, id: \.self) { index in
          dot(filled: missed || index < entry.count)
        }
      }
      .labShake(trigger: shakes)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Numbers typed")
      .accessibilityValue("\(entry.count) of \(GateChallenge.length)")

      Text("Those numbers don’t match. Try again.")
        .font(.system(.body, design: .rounded, weight: .medium))
        .foregroundStyle(LabColor.retry)
        .multilineTextAlignment(.center)
        .opacity(missed ? 1 : 0)
        .accessibilityHidden(!missed)
    }
    .frame(maxWidth: .infinity)
  }

  private func dot(filled: Bool) -> some View {
    let color = missed ? LabColor.retry : LabColor.label
    return Circle()
      .fill(filled ? color : .clear)
      .overlay(Circle().strokeBorder(filled ? color : color.opacity(0.5), lineWidth: 1.5))
      .frame(width: 16, height: 16)
  }

  private func keypad(_ layout: KeypadLayout) -> some View {
    Grid(horizontalSpacing: 28, verticalSpacing: layout.rowGap) {
      ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
        GridRow {
          ForEach(row, id: \.self) { digitKey($0, size: layout.key) }
        }
      }
      GridRow {
        if layout.cancelInKeypad {
          Button("Cancel", action: leave)
            .font(LabFont.label)
            .foregroundStyle(LabColor.primaryInk)
            .frame(width: layout.key, height: layout.key)
            .contentShape(Circle())
        } else {
          Color.clear
            .frame(width: layout.key, height: layout.key)
            .accessibilityHidden(true)
        }
        digitKey(0, size: layout.key)
        deleteKey(size: layout.key)
      }
    }
    .disabled(passed)
  }

  private func digitKey(_ digit: Int, size: CGFloat) -> some View {
    Button {
      type(digit)
    } label: {
      Text(digit, format: .number)
        .font(.system(size: 32 * size / 84, weight: .medium, design: .rounded))
        .foregroundStyle(LabColor.primaryInk)
        .frame(width: size, height: size)
    }
    .buttonStyle(GateKeyStyle())
    .accessibilityLabel(Text(digit, format: .number))
  }

  /// Removes the last digit; hidden while nothing is typed.
  private func deleteKey(size: CGFloat) -> some View {
    Button("Delete") {
      entry.removeLast()
    }
    .font(LabFont.label)
    .foregroundStyle(LabColor.primaryInk)
    .frame(width: size, height: size)
    .contentShape(Circle())
    .opacity(entry.isEmpty ? 0 : 1)
    .disabled(entry.isEmpty)
    .accessibilityHidden(entry.isEmpty)
  }

  private func type(_ digit: Int) {
    guard !passed, entry.count < GateChallenge.length else { return }
    missed = false
    entry.append(digit)
    guard entry.count == GateChallenge.length else { return }
    if entry == challenge.digits {
      passed = true
      pass()
    } else {
      miss()
    }
  }

  /// 7.3b · A wrong code resets quietly: lavender dots, one shake, new digits.
  private func miss() {
    wrongTries += 1
    guard wrongTries < 3 else {
      leave()
      return
    }
    missed = true
    entry = []
    challenge = GateChallenge.make(after: challenge)
    if !reduceMotion { shakes += 1 }
    AccessibilityNotification.Announcement("Those numbers don’t match. Try again.").post()
  }
}

/// The keypad at its designed size (84 pt keys), or fitted to a short screen such as the outer
/// display: Cancel moves into the keypad’s empty corner and the keys shrink only as far as needed.
private struct KeypadLayout {
  var key: CGFloat = 84
  var rowGap: CGFloat = 22
  var entryGap: CGFloat = 48
  var keypadGap: CGFloat = 30
  var cancelInKeypad = false

  init() {}

  init(height: CGFloat) {
    let header: CGFloat = 71
    let entry: CGFloat = 58
    let cancelRow: CGFloat = 24 + 56
    let designed = header + entryGap + entry + keypadGap + 4 * key + 3 * rowGap + cancelRow
    guard height < designed else { return }
    cancelInKeypad = true
    entryGap = 20
    keypadGap = 16
    rowGap = 14
    let room = height - header - entryGap - entry - keypadGap - 3 * rowGap
    key = max(56, min(84, (room / 4).rounded(.down)))
  }
}

/// Three digits a grown-up types from their written-out names.
struct GateChallenge: Equatable {
  static let length = 3
  var digits: [Int]

  var prompt: String {
    "Type the numbers " + digits.map { Self.names[$0] }.joined(separator: ", ") + "."
  }

  /// New digits every time, never the same code twice in a row.
  static func make(after previous: GateChallenge? = nil) -> GateChallenge {
    var next: GateChallenge
    repeat {
      next = GateChallenge(digits: (0..<length).map { _ in Int.random(in: 0...9) })
    } while next == previous
    return next
  }

  private static let names = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
}

/// An 84 pt glass key that brightens while pressed.
private struct GateKeyStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(.white.opacity(configuration.isPressed ? 0.24 : 0.09), in: Circle())
      .overlay(Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1))
      .contentShape(Circle())
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
