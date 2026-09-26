import SwiftUI

struct GlassPondView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var session = GlassPondSession()
  @State private var showsHint = false
  @State private var showsJournal = false

  var body: some View {
    roomLayout
      .background(PondPalette.nightGradient)
      .navigationBarBackButtonHidden()
      .toolbarBackground(.hidden, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Map", systemImage: "map") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Restart room", systemImage: "arrow.counterclockwise") { session.reset() }
        }
        if session.stage != .entrance && session.stage != .prediction {
          ToolbarItemGroup(placement: .bottomBar) {
            Button("Hint", systemImage: "lightbulb") { showsHint = true }
            Button("Journal", systemImage: "book.closed") { showsJournal = true }
          }
        }
      }
      .sheet(isPresented: $showsHint) {
        PondInfoSheet(
          title: "A little hint",
          message: session.stage == .challenge
            ? "Remember the tipping point. Tilt the light past 42° so it stays inside the crystal vine."
            : "Watch the surface. What changes when the light reaches it at a steeper angle?"
        )
      }
      .sheet(isPresented: $showsJournal) {
        PondJournalSheet(session: session)
      }
      .sensoryFeedback(.selection, trigger: session.thresholdCrossings)
      .sensoryFeedback(.success, trigger: session.wins)
      .preferredColorScheme(.dark)
      .tint(PondPalette.pond)
  }

  @ViewBuilder
  private var roomLayout: some View {
    if #available(iOS 27.1, *) {
      ArrangementView {
        PondControlPanel(session: session)
      } secondary: {
        PondSceneView(session: session)
      }
      .arrangementViewStyle(.split)
      .onHingeChange { _, context in
        session.receiveHinge(context)
      }
    } else {
      GeometryReader { geometry in
        if geometry.size.width > geometry.size.height {
          HStack(spacing: 0) {
            PondSceneView(session: session)
            PondControlPanel(session: session)
          }
        } else {
          VStack(spacing: 0) {
            PondSceneView(session: session)
            PondControlPanel(session: session)
          }
        }
      }
    }
  }
}

private struct PondInfoSheet: View {
  @Environment(\.dismiss) private var dismiss
  var title: String
  var message: String

  var body: some View {
    NavigationStack {
      ContentUnavailableView {
        Label(title, systemImage: "sparkles")
      } description: {
        Text(message)
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium])
  }
}

private struct PondJournalSheet: View {
  @Environment(\.dismiss) private var dismiss
  var session: GlassPondSession

  var body: some View {
    NavigationStack {
      List {
        Section("The Glass Pond") {
          Label("Guess made", systemImage: session.earnedGuess ? "sparkle" : "circle")
          Label("Answer found", systemImage: session.earnedAnswer ? "sparkle" : "circle")
          Label("Moon lily awakened", systemImage: session.earnedChallenge || session.previouslyCompleted ? "sparkle" : "circle")
        }
        if session.previouslyCompleted {
          Section {
            Text("Light stayed inside the crystal vine when it passed the glass-to-air tipping point.")
          } header: {
            Text("Discovery")
          }
        }
      }
      .navigationTitle("Journal")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
}
