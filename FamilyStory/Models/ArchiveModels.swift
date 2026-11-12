import Foundation
import SwiftData

@Model
final class Memory {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var recordedAt: Date
    var eventDate: Date?
    var audioFilename: String?
    var duration: TimeInterval
    var createdAt: Date
    var people: [Person]

    init(title: String = "Câu chuyện chưa đặt tên", notes: String = "",
         recordedAt: Date = .now, eventDate: Date? = nil,
         audioFilename: String? = nil, duration: TimeInterval = 0) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.recordedAt = recordedAt
        self.eventDate = eventDate
        self.audioFilename = audioFilename
        self.duration = duration
        self.createdAt = .now
        self.people = []
    }
}

@Model
final class Person {
    @Attribute(.unique) var id: UUID
    var name: String
    var relationship: String
    var notes: String
    var createdAt: Date
    @Relationship(inverse: \\Memory.people) var memories: [Memory]

    init(name: String, relationship: String = "", notes: String = "") {
        self.id = UUID()
        self.name = name
        self.relationship = relationship
        self.notes = notes
        self.createdAt = .now
        self.memories = []
    }
}

enum ArchiveStorage {
    static var audioDirectory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documents.appendingPathComponent("FamilyStory/Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func audioURL(filename: String) -> URL {
        audioDirectory.appendingPathComponent(filename)
    }
}