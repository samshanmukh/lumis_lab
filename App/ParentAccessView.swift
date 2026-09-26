import SwiftUI

struct ParentAccessView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var challenge = ParentChallenge.make()
  @State private var answer = ""
  @State private var errorMessage: String?
  @State private var isVerified = false

  private let columns = Array(repeating: GridItem(.flexible()), count: 3)

  var body: some View {
    NavigationStack {
      Group {
        if isVerified {
          ParentSubscriptionsView()
        } else {
          challengeScreen
        }
      }
      .navigationTitle(isVerified ? "Grown-ups" : "")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Close", systemImage: "xmark") { dismiss() }
            .labelStyle(.iconOnly)
        }
      }
    }
    .tint(isVerified ? .indigo : .white)
  }

  private var challengeScreen: some View {
    ScrollView {
      VStack(spacing: 24) {
        HStack(spacing: 7) {
          Circle().fill(.yellow).frame(width: 7, height: 7)
          Circle().fill(.white.opacity(0.45)).frame(width: 7, height: 7)
          Circle().fill(.white.opacity(0.45)).frame(width: 7, height: 7)
        }
        .accessibilityHidden(true)
        .padding(.top, 32)

        VStack(spacing: 8) {
          Text("For grown-ups")
            .font(.largeTitle.bold())
          Text("Solve this quick question to manage Lumi’s Lab Plus.")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.76))
            .multilineTextAlignment(.center)
        }

        Text(challenge.question)
          .font(.title2.weight(.semibold))
          .padding(.top, 8)

        HStack(spacing: 14) {
          ForEach(0..<challenge.answerDigits, id: \.self) { index in
            Circle()
              .fill(index < answer.count ? .white : .white.opacity(0.3))
              .frame(width: 13, height: 13)
          }
        }
        .frame(height: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Answer, \(answer.count) of \(challenge.answerDigits) digits entered")

        if let errorMessage {
          Text(errorMessage)
            .font(.subheadline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
        }

        LazyVGrid(columns: columns, spacing: 14) {
          ForEach(1...9, id: \.self) { digit in
            digitButton(digit)
          }
          Color.clear.frame(width: 64, height: 64).accessibilityHidden(true)
          digitButton(0)
          Button {
            if !answer.isEmpty { answer.removeLast() }
          } label: {
            Image(systemName: "delete.left")
              .font(.title3)
              .frame(width: 64, height: 64)
              .background(.white.opacity(0.12), in: Circle())
          }
          .accessibilityLabel("Delete last digit")
          .disabled(answer.isEmpty)
        }
        .frame(maxWidth: 260)

        Button("Continue") { verifyAnswer() }
          .font(.headline)
          .foregroundStyle(.indigo)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(.white, in: Capsule())
          .disabled(answer.count != challenge.answerDigits)
          .opacity(answer.count == challenge.answerDigits ? 1 : 0.6)

        Button("Cancel") { dismiss() }
          .font(.subheadline)
          .padding(.bottom, 12)
      }
      .frame(maxWidth: 420)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 24)
    }
    .foregroundStyle(.white)
    .background {
      LinearGradient(
        colors: [Color(red: 0.12, green: 0.08, blue: 0.37), Color(red: 0.28, green: 0.22, blue: 0.68)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
    }
  }

  private func digitButton(_ digit: Int) -> some View {
    Button {
      guard answer.count < challenge.answerDigits else { return }
      answer.append(String(digit))
      errorMessage = nil
    } label: {
      Text(digit.formatted())
        .font(.title3.weight(.medium))
        .frame(width: 64, height: 64)
        .background(.white.opacity(0.12), in: Circle())
    }
    .accessibilityLabel("Number \(digit)")
  }

  private func verifyAnswer() {
    if Int(answer) == challenge.answer {
      isVerified = true
      errorMessage = nil
    } else {
      answer = ""
      challenge = ParentChallenge.make()
      errorMessage = "That answer didn’t match. Try this new question."
    }
  }
}

private struct ParentChallenge {
  var first: Int
  var second: Int

  var question: String { "What is \(first) × \(second)?" }
  var answer: Int { first * second }
  var answerDigits: Int { String(answer).count }

  static func make() -> ParentChallenge {
    ParentChallenge(first: Int.random(in: 13...19), second: Int.random(in: 7...9))
  }
}
