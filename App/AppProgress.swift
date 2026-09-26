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

  var vignetteName: String {
    switch self {
    case .mirror: "MirrorVignette"
    case .glassPond: "GlassVignette"
    case .marbleRamp: "MarbleVignette"
    case .launchAngle: "LaunchVignette"
    }
  }

  var number: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }

  /// The name after “the”, as in “After the Glass Pond”.
  var shortTitle: String {
    switch self {
    case .mirror: "Mirror Room"
    case .glassPond: "Glass Pond"
    case .marbleRamp: "Marble Ramp"
    case .launchAngle: "Launch Angle"
    }
  }

  /// Rooms built so far. The others show on the journey but can’t be started yet.
  var isPlayable: Bool { self != .launchAngle }

  /// Most rooms open once the one before is done. The Marble Ramp arrived as its own
  /// chapter and can be played any time.
  var opensInOrder: Bool { self != .marbleRamp }

  /// Book rooms open straight from the closed phone; laptop rooms turn sideways first.
  var playsLikeLaptop: Bool { self != .mirror }

  var next: RoomID? {
    let rooms = Self.allCases
    guard let index = rooms.firstIndex(of: self), index + 1 < rooms.count else { return nil }
    return rooms[index + 1]
  }

  var previous: RoomID? {
    let rooms = Self.allCases
    guard let index = rooms.firstIndex(of: self), index > 0 else { return nil }
    return rooms[index - 1]
  }

  /// The journey’s question for the room you can start next.
  var question: String {
    switch self {
    case .mirror: "How many Lumis can two mirrors make?"
    case .glassPond: "Can light get stuck in glass?"
    case .marbleRamp: "Wake the firefly with the Duo hinge"
    case .launchAngle: ""
    }
  }

  /// The story line above the room’s door.
  var storyLine: String {
    switch self {
    case .mirror: "Lumi is alone in the dark. Can mirrors make friends for her?"
    case .glassPond: "Lumi fell into a pond of magic glass. Can her light wake the moon lily?"
    case .marbleRamp: "A firefly fell asleep at the end of the path. Can Lumi’s marble roll far enough to wake it?"
    case .launchAngle: "The moon bed is far away. Can Lumi throw her light into it?"
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
