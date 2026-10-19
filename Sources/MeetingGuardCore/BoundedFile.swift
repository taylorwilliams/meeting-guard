import Foundation

public enum BoundedFile {
    public static func read(_ url: URL, limit: Int) throws -> Data {
        guard limit > 0 && limit < Int.max else { throw CocoaError(.fileReadTooLarge) }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else { throw CocoaError(.fileReadUnsupportedScheme) }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: limit + 1) ?? Data()
        guard data.count <= limit else { throw CocoaError(.fileReadTooLarge) }
        return data
    }
}
