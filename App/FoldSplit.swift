import SwiftUI

/// Two regions either side of the fold: side by side when the space is wider than tall,
/// stacked when taller than wide. The first region is leading (or top), the second trailing
/// (or bottom), so a room’s artwork stays on one half and its questions on the other.
struct FoldSplit {
  var first: CGRect
  var second: CGRect

  var isSideBySide: Bool { second.minX >= first.maxX }

  init(size: CGSize, insets: EdgeInsets, foldX: CGFloat, gap: CGFloat = 20, tallFirstShare: CGFloat = 0.42) {
    let content = CGRect(
      x: insets.leading,
      y: insets.top,
      width: max(0, size.width - insets.leading - insets.trailing),
      height: max(0, size.height - insets.top - insets.bottom)
    )
    if size.width > size.height {
      first = CGRect(x: content.minX, y: content.minY, width: max(0, foldX - gap - content.minX), height: content.height)
      second = CGRect(x: foldX + gap, y: content.minY, width: max(0, content.maxX - foldX - gap), height: content.height)
    } else {
      let split = content.height * tallFirstShare
      first = CGRect(x: content.minX, y: content.minY, width: content.width, height: split)
      second = CGRect(x: content.minX, y: content.minY + split, width: content.width, height: content.height - split)
    }
  }

  /// The fold’s x position when the phone opens like a book, or the middle of the space.
  static func foldX(in proxy: GeometryProxy) -> CGFloat {
    if let region = proxy.reservedRegions(kind: .division, options: .includeInactive).first,
       region.frame.height > region.frame.width {
      return region.frame.midX
    }
    return proxy.size.width / 2
  }
}

extension View {
  /// Places a view in a rectangle of its parent’s coordinate space.
  func place(in rect: CGRect) -> some View {
    frame(width: rect.width, height: rect.height)
      .offset(x: rect.minX, y: rect.minY)
  }
}
