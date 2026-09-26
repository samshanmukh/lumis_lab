import Foundation
import Observation

@Observable
final class AppModel {
  private(set) var progress: LabProgress

  init() {
    progress = Self.load() ?? LabProgress()
  }

  var mirror: RoomState { room(.mirror) }

  func room(_ id: RoomID) -> RoomState { progress.rooms[id] ?? RoomState() }

  var earnedFireflies: Int { progress.rooms.values.reduce(0) { $0 + $1.fireflies.count } }

  func markWelcomeSeen() {
    progress.welcomeSeen = true
    save()
  }

  func setStep(_ step: RoomStep, room: RoomID = .mirror) {
    var state = progress.rooms[room] ?? RoomState()
    state.step = step
    progress.rooms[room] = state
    progress.lastRoom = room
    save()
  }

  func updateRoom(_ room: RoomID = .mirror, _ change: (inout RoomState) -> Void) {
    var state = progress.rooms[room] ?? RoomState()
    change(&state)
    progress.rooms[room] = state
    progress.lastRoom = room
    save()
  }

  func save() {
    do {
      let url = try Self.storageURL()
      let data = try JSONEncoder().encode(progress)
      try data.write(to: url, options: .atomic)
    } catch {
      assertionFailure("Could not save Lumi's Lab progress: \(error)")
    }
  }

  private static func load() -> LabProgress? {
    guard let url = try? storageURL(), let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(LabProgress.self, from: data)
  }

  private static func storageURL() throws -> URL {
    let directory = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    return directory.appendingPathComponent("LumisLabProgress.json")
  }
}
