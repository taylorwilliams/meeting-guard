import Foundation

public struct SavedState: Codable, Sendable {
    public var schemaVersion = 1
    public var settings = GuardSettings()
    public var reminders: [LocalReminder] = []
    public var ledger = AlertLedger()
    public init() {}
}

public struct StateStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func load() throws -> SavedState {
        guard FileManager.default.fileExists(atPath: url.path) else { return .init() }
        let state = try JSONDecoder().decode(SavedState.self, from: Data(contentsOf: url))
        guard state.schemaVersion == 1 else { throw CocoaError(.coderReadCorrupt) }
        return state
    }

    public func save(_ state: SavedState) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
