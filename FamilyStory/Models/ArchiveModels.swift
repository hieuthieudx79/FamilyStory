import Foundation
import SwiftData

@Model
final class Memory {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var transcript: String
    var recordedAt: Date
    var eventDate: Date?
    var audioFilename: String?
    var photoFilename: String?
    var duration: TimeInterval
    var createdAt: Date
    var people: [Person]

    init(
        id: UUID = UUID(),
        title: String = "Câu chuyện chưa đặt tên",
        notes: String = "",
        transcript: String = "",
        recordedAt: Date = .now,
        eventDate: Date? = nil,
        audioFilename: String? = nil,
        photoFilename: String? = nil,
        duration: TimeInterval = 0,
        people: [Person] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.transcript = transcript
        self.recordedAt = recordedAt
        self.eventDate = eventDate
        self.audioFilename = audioFilename
        self.photoFilename = photoFilename
        self.duration = duration
        self.createdAt = .now
        self.people = people
    }
}

@Model
final class Person {
    @Attribute(.unique) var id: UUID
    var name: String
    var relationship: String
    var notes: String
    var createdAt: Date
    @Relationship(inverse: \Memory.people) var memories: [Memory]

    init(
        id: UUID = UUID(),
        name: String,
        relationship: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.notes = notes
        self.createdAt = .now
        self.memories = []
    }
}

enum ArchiveStorage {
    static var rootDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FamilyStory", isDirectory: true)
    }

    static var audioDirectory: URL {
        rootDirectory.appendingPathComponent("Audio", isDirectory: true)
    }

    static var photoDirectory: URL {
        rootDirectory.appendingPathComponent("Photos", isDirectory: true)
    }

    static func prepareDirectories() throws {
        try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: photoDirectory, withIntermediateDirectories: true)
    }

    static func isSafeFilename(_ filename: String) -> Bool {
        guard !filename.isEmpty, filename.count <= 180,
              !filename.contains("/"), !filename.contains("\\"),
              filename != ".", filename != ".." else { return false }
        return filename.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || "._-".unicodeScalars.contains($0)
        }
    }

    static func audioURL(filename: String) -> URL {
        audioDirectory.appendingPathComponent(filename, isDirectory: false)
    }

    static func photoURL(filename: String) -> URL {
        photoDirectory.appendingPathComponent(filename, isDirectory: false)
    }

    static func storageUsage() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }

    static func formattedSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
