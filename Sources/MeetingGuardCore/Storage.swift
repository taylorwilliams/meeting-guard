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
        try validateFile(url)
        let state = try JSONDecoder().decode(SavedState.self, from: BoundedFile.read(url, limit: 32 * 1024 * 1024))
        guard state.schemaVersion == 1 else { throw CocoaError(.coderReadCorrupt) }
        return state
    }

    public func save(_ state: SavedState) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        guard attributes[.type] as? FileAttributeType == .typeDirectory,
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid() else { throw CocoaError(.fileWriteNoPermission) }
        // Restrict an existing directory before the atomic write creates any data.
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        if FileManager.default.fileExists(atPath: url.path) { try validateFile(url) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func validateFile(_ url: URL) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid() else { throw CocoaError(.fileReadNoPermission) }
    }
}
