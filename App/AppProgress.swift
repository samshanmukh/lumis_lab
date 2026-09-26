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
