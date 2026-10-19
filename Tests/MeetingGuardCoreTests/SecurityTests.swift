import Foundation
import Testing
@testable import MeetingGuardCore

@Test func automationLinksAreDisabledForNewAndExistingSettings() throws {
    #expect(GuardSettings().automationLinksEnabled != true)
    var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(GuardSettings())) as! [String: Any]
    object.removeValue(forKey: "automationLinksEnabled")
    let restored = try JSONDecoder().decode(GuardSettings.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(restored.automationLinksEnabled != true)
}

@Test func automationRejectsAmbiguousAndOversizedInputs() {
    let cases = [
        "meetingguard://user@alert?title=Test", "meetingguard://alert:123?title=Test",
        "meetingguard://alert/unknown?title=Test", "meetingguard://alert?title=Test#fragment",
        "meetingguard://alert?title=Test&execute=anything", "meetingguard://alert?title=one%0Atwo",
        "meetingguard://alert?title=Test&notes=" + String(repeating: "a", count: 16_384)
    ]
    for value in cases { #expect(DeepLink.alert(from: URL(string: value)!, now: Date()) == nil) }
}

@Test func automationPromptsAreRateLimited() {
    var limit = AutomationRateLimit()
    let results = [limit.allow(at: 100), limit.allow(at: 100), limit.allow(at: 109.9), limit.allow(at: 110)]
    #expect(results == [true, false, false, true])
}

@Test func meetingLinksRequireEncryptedStandardConnections() {
    #expect(MeetingLink.find(in: ["http://meet.google.com/abc-defg-hij"]) == nil)
    #expect(MeetingLink.find(in: ["https://meet.google.com:8443/abc-defg-hij"]) == nil)
    #expect(MeetingLink.find(in: ["https://meet.google.com:443/abc-defg-hij"]) != nil)
}

@Test func oversizedImportsAreRejectedBeforeReadingTheWholeFile() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("theme.json")
    try Data(repeating: 32, count: 65_537).write(to: file)
    #expect(throws: (any Error).self) { try BoundedFile.read(file, limit: 65_536) }
    #expect(throws: (any Error).self) { try BoundedFile.read(directory, limit: 65_536) }
    try Data("{}".utf8).write(to: file)
    #expect(try BoundedFile.read(file, limit: 65_536) == Data("{}".utf8))
}

@Test func savingRepairsAnExistingStateDirectorysPermissions() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o755])
    defer { try? FileManager.default.removeItem(at: directory) }
    try StateStore(url: directory.appendingPathComponent("state.json")).save(.init())
    let attributes = try FileManager.default.attributesOfItem(atPath: directory.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
}

@Test func stateStoreDoesNotFollowFileOrDirectorySymlinks() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let target = directory.appendingPathComponent("target.json")
    let data = try JSONEncoder().encode(SavedState())
    try data.write(to: target)
    let link = directory.appendingPathComponent("state.json")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
    let store = StateStore(url: link)
    #expect(throws: (any Error).self) { try store.load() }
    #expect(throws: (any Error).self) { try store.save(.init()) }
    #expect(try Data(contentsOf: target) == data)
    let folderLink = directory.appendingPathComponent("linked")
    let folder = directory.appendingPathComponent("actual")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(at: folderLink, withDestinationURL: folder)
    #expect(throws: (any Error).self) { try StateStore(url: folderLink.appendingPathComponent("state.json")).save(.init()) }
}
