import SwiftUI

/// The frame every grown-ups screen shares: the night sky and 40 pt margins, laid out from its
/// container. Taller than wide it is one column; opened like a book it is two pages, each kept
/// 40 pt clear of the fold.
struct GrownUpsPage<Content: View>: View {
  @ViewBuilder var content: (FoldSplit) -> Content

  var body: some View {
    GeometryReader { proxy in
      let split = FoldSplit(
        size: proxy.size,
        insets: EdgeInsets(top: 40, leading: 40, bottom: 40, trailing: 40),
        foldX: FoldSplit.foldX(in: proxy),
        gap: 40
      )
      ZStack(alignment: .topLeading) {
        Color.clear
        content(split)
      }
      .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
    }
    .background(LabBackdrop())
  }
}

extension FoldSplit {
  /// The whole content area, for a screen laid out as one column.
  var column: CGRect { first.union(second) }
}

/// Lumi above a title and a line, with the actions at the bottom (7.2, 7.5, 7.6). Opened like
/// a book, Lumi takes the first page and the words and actions the second.
struct LumiMessagePage<Decoration: View, Actions: View>: View {
  var mood: LumiMood
  var title: String
  var line: String
  /// How much of a one-column screen Lumi’s space takes above the words.
  var lumiShare: CGFloat = 0.42
  @ViewBuilder var decoration: Decoration
  @ViewBuilder var actions: Actions

  var body: some View {
    GrownUpsPage { split in
      if split.isSideBySide {
        lumi.place(in: split.first)
        VStack(alignment: .leading, spacing: 0) {
          Spacer(minLength: 0)
          message
          Spacer(minLength: 40)
          actionRow
        }
        .place(in: split.second)
      } else {
        VStack(alignment: .leading, spacing: 0) {
          lumi.frame(height: max(200, split.column.height * lumiShare))
          message
          Spacer(minLength: 40)
          actionRow
        }
        .place(in: split.column)
      }
    }
  }

  private var lumi: some View {
    ZStack {
      decoration
      LumiView(mood: mood, radius: 74)
        .accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var message: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(LabFont.display)
        .foregroundStyle(LabColor.primaryInk)
        .accessibilityAddTraits(.isHeader)
      Text(line)
        .font(LabFont.body)
        .foregroundStyle(LabColor.secondaryInk)
    }
    .fixedSize(horizontal: false, vertical: true)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var actionRow: some View {
    HStack(spacing: 16) {
      actions
    }
  }
}

extension LumiMessagePage where Decoration == EmptyView {
  init(mood: LumiMood, title: String, line: String, @ViewBuilder actions: () -> Actions) {
    self.init(mood: mood, title: title, line: line, decoration: { EmptyView() }, actions: actions)
  }
}
