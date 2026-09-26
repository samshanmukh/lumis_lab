import SwiftUI

struct LabHomeView: View {
  @State private var showingParentArea = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Image(systemName: "atom")
            .font(.system(size: 58, weight: .light))
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 8) {
            Text("Science you can fold")
              .font(.largeTitle.bold())
            Text("A playful place to predict, experiment, and discover with Lumi.")
              .font(.body)
              .foregroundStyle(.secondary)
          }

          VStack(alignment: .leading, spacing: 8) {
            Label("The Mirror Room", systemImage: "sparkles")
              .font(.headline)
            Text("Lumi’s first experiment is coming soon.")
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(20)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))

          NavigationLink {
            GlassPondView()
          } label: {
            VStack(alignment: .leading, spacing: 8) {
              Label("The Glass Pond", systemImage: "water.waves")
                .font(.headline)
              Text("Tilt Lumi’s light, discover the tipping point, and wake the moon lily.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
              Text("Play Room 2")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18))
          }
          .buttonStyle(.plain)
        }
        .frame(maxWidth: 600, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(24)
      }
      .navigationTitle("Lumi’s Lab")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Parent area", systemImage: "person.crop.circle") {
            showingParentArea = true
          }
          .labelStyle(.iconOnly)
        }
      }
      .sheet(isPresented: $showingParentArea) {
        ParentAccessView()
      }
    }
  }
}
