import Foundation

enum RoomID: String, Codable, CaseIterable, Identifiable {
  case mirror
  case glassPond
  case marbleRamp
  case launchAngle

  var id: String { rawValue }

  var title: String {
    switch self {
    case .mirror: "The Mirror Room"
    case .glassPond: "The Glass Pond"
    case .marbleRamp: "Marble Ramp"
    case .launchAngle: "Launch Angle"
    }
  }

  /// The name on the room’s door sign.
  var signName: String {
    switch self {
    case .marbleRamp: "The Marble Ramp"
    default: title
    }
  }

  /// The number on the room’s door sign.
  var number: Int {
    switch self {
    case .mirror: 1
    case .glassPond: 2
    case .marbleRamp: 3
    case .launchAngle: 4
    }
  }

  var story: String {
    switch self {
    case .mirror: "Lumi is alone in the dark. Can mirrors make friends for her?"
    case .glassPond: "A moon lily is asleep under the glass. Can Lumi’s light reach it?"
    case .marbleRamp: "A firefly fell asleep at the end of the path. Can Lumi’s marble roll far enough to wake it?"
    case .launchAngle: "The moon bed is far away. Can Lumi throw her light into it?"
    }
  }

  /// Rooms that can be played in this build. The others show “Coming soon”.
  var isBuilt: Bool {
    switch self {
    case .mirror, .marbleRamp: true
    case .glassPond, .launchAngle: false
    }
  }

  /// Rooms played like a laptop: the door turns on its side before it opens.
  var isLaptopRoom: Bool { self != .mirror }

  /// The next room along the journey, if any.
  var next: RoomID? {
    let all = Self.allCases
    guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
    return all[index + 1]
  }

  var vignetteName: String {
    switch self {
    case .mirror: "MirrorVignette"
    case .glassPond: "GlassVignette"
    case .marbleRamp: "MarbleVignette"
    case .launchAngle: "LaunchVignette"
    }
  }
}

enum RoomStep: String, Codable {
  case door
  case checkpoint1
  case tryIt
  case check
  case why
  case checkpoint2
  case challenge
  case solved
  case roomEnd

  var isCheckpoint: Bool { self == .checkpoint1 || self == .checkpoint2 }

  var progressIndex: Int {
    switch self {
    case .door: 0
    case .checkpoint1: 1
    case .tryIt: 2
    case .check: 3
    case .why: 4
    case .checkpoint2: 5
    case .challenge, .solved, .roomEnd: 6
    }
  }
}

enum Firefly: String, Codable, Hashable, CaseIterable {
  case guess
  case answer
  case challenge
}

struct RoomState: Codable {
  var step: RoomStep = .door
  var guess: Int?
  var checkpoints: [Int: String] = [:]
  var wrongTries: Int = 0
  var fireflies: Set<Firefly> = []
  var solved = false
}

struct LabProgress: Codable {
  var welcomeSeen = false
  var rooms: [RoomID: RoomState] = [.mirror: RoomState()]
  var lastRoom: RoomID? = .mirror
}
