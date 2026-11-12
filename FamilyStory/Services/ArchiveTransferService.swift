import CryptoKit
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let familyStoryArchive = UTType(exportedAs: "com.hieuthieudx79.familystory.archive")
}

struct FamilyArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.familyStoryArchive] }
    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw ArchiveTransferError.invalidPackage("Tệp archive không chứa dữ liệu.")
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum ArchiveAssetKind: String, Codable {
    case audio
    case photo

    var directoryName: String {
        switch self {
        case .audio: return "Audio"
        case .photo: return "Photos"
        }
    }
}

struct ArchivePersonRecord: Codable {
    let id: UUID
    let name: String
    let relationship: String
    let notes: String
}

struct ArchiveMemoryRecord: Codable {
    let id: UUID
    let title: String
    let notes: String
    let transcript: String
    let recordedAt: Date
    let eventDate: Date?
    let audioFilename: String?
    let photoFilename: String?
    let duration: TimeInterval
    let personIDs: [UUID]
}

struct ArchiveAssetRecord: Codable {
    let kind: ArchiveAssetKind
    let filename: String
    let sha256: String
    let byteCount: Int
    var key: String { "\(kind.rawValue)/\(filename)" }
    var archivePath: String { "\(kind.directoryName)/\(filename)" }
}

struct ArchiveManifest: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let people: [ArchivePersonRecord]
    let memories: [ArchiveMemoryRecord]
    let assets: [ArchiveAssetRecord]
}

struct ValidatedFamilyArchive {
    fileprivate let manifest: ArchiveManifest
    fileprivate let files: [String: Data]

    var peopleCount: Int { manifest.people.count }
    var memoryCount: Int { manifest.memories.count }
    var audioCount: Int { manifest.assets.filter { $0.kind == .audio }.count }
    var photoCount: Int { manifest.assets.filter { $0.kind == .photo }.count }
}

struct ArchiveImportResult {
    let importedMemories: Int
    let importedPeople: Int
    let skippedMemories: Int
}

enum ArchiveTransferError: LocalizedError {
    case invalidPackage(String)
    case unsupportedVersion
    case missingAsset(String)
    case checksumMismatch(String)
    case archiveTooLarge
    case unsafePath
    case duplicateIdentifier
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPackage(let reason): return reason
        case .unsupportedVersion: return "Phiên bản archive này không được hỗ trợ."
        case .missingAsset(let name): return "Không tìm thấy tệp đính kèm: \(name)."
        case .checksumMismatch(let name): return "Tệp đính kèm bị thay đổi hoặc hỏng: \(name)."
        case .archiveTooLarge: return "Archive vượt quá giới hạn an toàn 1 GB."
        case .unsafePath: return "Archive chứa đường dẫn tệp không an toàn."
        case .duplicateIdentifier: return "Archive có mã định danh trùng lặp."
        case .importFailed(let reason): return "Không thể nhập archive: \(reason)"
        }
    }
}

enum ArchiveTransferService {
    private static let currentSchemaVersion = 1
    private static let maximumArchiveBytes = 1_000_000_000
    private static let maximumAssetBytes = 300_000_000

    static func makeArchive(memories: [Memory], people: [Person]) throws -> Data {
        try ArchiveStorage.prepareDirectories()

        let memoryRecords = memories.map {
            ArchiveMemoryRecord(
                id: $0.id,
                title: $0.title,
                notes: $0.notes,
                transcript: $0.transcript,
                recordedAt: $0.recordedAt,
                eventDate: $0.eventDate,
                audioFilename: $0.audioFilename,
                photoFilename: $0.photoFilename,
                duration: $0.duration,
                personIDs: $0.people.map(\.id)
            )
        }

        let peopleRecords = people.map {
            ArchivePersonRecord(id: $0.id, name: $0.name, relationship: $0.relationship, notes: $0.notes)
        }

        var assets: [ArchiveAssetRecord] = []
        var zipFiles: [(String, Data)] = []

        for memory in memories {
            if let filename = memory.audioFilename {
                guard ArchiveStorage.isSafeFilename(filename) else { throw ArchiveTransferError.unsafePath }
                let data = try readAsset(at: ArchiveStorage.audioURL(filename: filename), name: filename)
                try appendAsset(data, kind: .audio, filename: filename, assets: &assets, files: &zipFiles)
            }
            if let filename = memory.photoFilename {
                guard ArchiveStorage.isSafeFilename(filename) else { throw ArchiveTransferError.unsafePath }
                let data = try readAsset(at: ArchiveStorage.photoURL(filename: filename), name: filename)
                try appendAsset(data, kind: .photo, filename: filename, assets: &assets, files: &zipFiles)
            }
        }

        let manifest = ArchiveManifest(
            schemaVersion: currentSchemaVersion,
            exportedAt: .now,
            people: peopleRecords,
            memories: memoryRecords,
            assets: assets
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let manifestData = try encoder.encode(manifest)
        zipFiles.insert(("manifest.json", manifestData), at: 0)

        let archive = try StoredZIP.make(files: zipFiles)
        guard archive.count <= maximumArchiveBytes else { throw ArchiveTransferError.archiveTooLarge }
        return archive
    }

    static func validateArchive(_ data: Data) throws -> ValidatedFamilyArchive {
        guard data.count <= maximumArchiveBytes else { throw ArchiveTransferError.archiveTooLarge }
        let files = try StoredZIP.extract(data, maximumTotalBytes: maximumArchiveBytes)
        guard let manifestData = files["manifest.json"], manifestData.count <= 20_000_000 else {
            throw ArchiveTransferError.invalidPackage("Archive thiếu manifest.json hoặc manifest quá lớn.")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest: ArchiveManifest
        do {
            manifest = try decoder.decode(ArchiveManifest.self, from: manifestData)
        } catch {
            throw ArchiveTransferError.invalidPackage("Không đọc được manifest: \(error.localizedDescription)")
        }

        guard manifest.schemaVersion == currentSchemaVersion else {
            throw ArchiveTransferError.unsupportedVersion
        }
        guard manifest.memories.count <= 10_000,
              manifest.people.count <= 2_000,
              manifest.assets.count <= 12_000 else {
            throw ArchiveTransferError.archiveTooLarge
        }

        let memoryIDs = manifest.memories.map(\.id)
        let personIDs = manifest.people.map(\.id)
        guard Set(memoryIDs).count == memoryIDs.count,
              Set(personIDs).count == personIDs.count else {
            throw ArchiveTransferError.duplicateIdentifier
        }

        let availablePeople = Set(personIDs)
        for memory in manifest.memories {
            guard memory.title.count <= 500,
                  memory.notes.count <= 20_000,
                  memory.transcript.count <= 1_000_000,
                  memory.duration >= 0,
                  memory.personIDs.allSatisfy({ availablePeople.contains($0) }) else {
                throw ArchiveTransferError.invalidPackage("Thông tin một câu chuyện không hợp lệ.")
            }
            if let name = memory.audioFilename, !ArchiveStorage.isSafeFilename(name) {
                throw ArchiveTransferError.unsafePath
            }
            if let name = memory.photoFilename, !ArchiveStorage.isSafeFilename(name) {
                throw ArchiveTransferError.unsafePath
            }
        }

        var expected = Set<String>()
        for asset in manifest.assets {
            guard ArchiveStorage.isSafeFilename(asset.filename),
                  asset.byteCount >= 0,
                  asset.byteCount <= maximumAssetBytes,
                  expected.insert(asset.archivePath).inserted else {
                throw ArchiveTransferError.unsafePath
            }
            guard let content = files[asset.archivePath] else {
                throw ArchiveTransferError.missingAsset(asset.filename)
            }
            guard content.count == asset.byteCount,
                  checksum(content) == asset.sha256 else {
                throw ArchiveTransferError.checksumMismatch(asset.filename)
            }
        }

        let referenced = Set(manifest.memories.flatMap { memory -> [String] in
            var names: [String] = []
            if let audio = memory.audioFilename { names.append("Audio/\(audio)") }
            if let photo = memory.photoFilename { names.append("Photos/\(photo)") }
            return names
        })
        guard referenced.isSubset(of: expected) else {
            throw ArchiveTransferError.invalidPackage("Manifest tham chiếu đến tệp không được đóng gói.")
        }

        let allowedPaths = expected.union(["manifest.json"])
        guard Set(files.keys) == allowedPaths else {
            throw ArchiveTransferError.invalidPackage("Archive chứa tệp không được khai báo trong manifest.")
        }

        return ValidatedFamilyArchive(manifest: manifest, files: files)
    }

    static func importArchive(
        _ archive: ValidatedFamilyArchive,
        into context: ModelContext
    ) throws -> ArchiveImportResult {
        var createdFiles: [URL] = []
        do {
            let existingMemories = try context.fetch(FetchDescriptor<Memory>())
            let existingPeople = try context.fetch(FetchDescriptor<Person>())
            let memoryIDs = Set(existingMemories.map(\.id))
            var peopleByID = Dictionary(uniqueKeysWithValues: existingPeople.map { ($0.id, $0) })

            var importedPeople = 0
            for record in archive.manifest.people where peopleByID[record.id] == nil {
                let person = Person(id: record.id, name: record.name, relationship: record.relationship, notes: record.notes)
                context.insert(person)
                peopleByID[record.id] = person
                importedPeople += 1
            }

            let newMemoryRecords = archive.manifest.memories.filter { !memoryIDs.contains($0.id) }
            let neededAssets = Set(newMemoryRecords.flatMap { record -> [String] in
                var keys: [String] = []
                if let name = record.audioFilename { keys.append("audio/\(name)") }
                if let name = record.photoFilename { keys.append("photo/\(name)") }
                return keys
            })

            var filenameMap: [String: String] = [:]
            try ArchiveStorage.prepareDirectories()

            for asset in archive.manifest.assets where neededAssets.contains(asset.key) {
                guard let content = archive.files[asset.archivePath] else {
                    throw ArchiveTransferError.missingAsset(asset.filename)
                }

                let folder = asset.kind == .audio ? ArchiveStorage.audioDirectory : ArchiveStorage.photoDirectory
                var targetName = asset.filename
                var destination = folder.appendingPathComponent(targetName)
                let digest = checksum(content)

                if FileManager.default.fileExists(atPath: destination.path) {
                    let current = try Data(contentsOf: destination, options: .mappedIfSafe)
                    if checksum(current) != digest {
                        targetName = "\(UUID().uuidString)-\(asset.filename)"
                        destination = folder.appendingPathComponent(targetName)
                    }
                }

                if !FileManager.default.fileExists(atPath: destination.path) {
                    try content.write(to: destination, options: .atomic)
                    createdFiles.append(destination)
                }
                filenameMap[asset.key] = targetName
            }

            for record in newMemoryRecords {
                let audioName = record.audioFilename.flatMap { filenameMap["audio/\($0)"] }
                let photoName = record.photoFilename.flatMap { filenameMap["photo/\($0)"] }
                let memory = Memory(
                    id: record.id,
                    title: record.title,
                    notes: record.notes,
                    transcript: record.transcript,
                    recordedAt: record.recordedAt,
                    eventDate: record.eventDate,
                    audioFilename: audioName,
                    photoFilename: photoName,
                    duration: record.duration,
                    people: record.personIDs.compactMap { peopleByID[$0] }
                )
                context.insert(memory)
            }

            try context.save()
            return ArchiveImportResult(
                importedMemories: newMemoryRecords.count,
                importedPeople: importedPeople,
                skippedMemories: archive.manifest.memories.count - newMemoryRecords.count
            )
        } catch {
            context.rollback()
            for url in createdFiles {
                try? FileManager.default.removeItem(at: url)
            }
            if let archiveError = error as? ArchiveTransferError {
                throw archiveError
            }
            throw ArchiveTransferError.importFailed(error.localizedDescription)
        }
    }

    private static func readAsset(at url: URL, name: String) throws -> Data {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= maximumAssetBytes else { throw ArchiveTransferError.archiveTooLarge }
            return data
        } catch let error as ArchiveTransferError {
            throw error
        } catch {
            throw ArchiveTransferError.missingAsset(name)
        }
    }

    private static func appendAsset(
        _ data: Data,
        kind: ArchiveAssetKind,
        filename: String,
        assets: inout [ArchiveAssetRecord],
        files: inout [(String, Data)]
    ) throws {
        let record = ArchiveAssetRecord(kind: kind, filename: filename, sha256: checksum(data), byteCount: data.count)
        if !assets.contains(where: { $0.key == record.key }) {
            assets.append(record)
            files.append((record.archivePath, data))
        }
    }

    private static func checksum(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private enum StoredZIP {
    private struct Entry {
        let name: String
        let crc: UInt32
        let size: UInt32
        let localOffset: UInt32
    }

    static func make(files: [(String, Data)]) throws -> Data {
        guard files.count <= 65_535 else { throw ArchiveTransferError.archiveTooLarge }
        var output = Data()
        var entries: [Entry] = []
        var names = Set<String>()

        for (name, content) in files {
            guard isSafeArchivePath(name), names.insert(name).inserted,
                  content.count <= Int(UInt32.max),
                  output.count <= Int(UInt32.max) else {
                throw ArchiveTransferError.unsafePath
            }

            let nameData = Data(name.utf8)
            let size = UInt32(content.count)
            let crc = crc32(content)
            let offset = UInt32(output.count)

            output.appendUInt32(0x04034b50)
            output.appendUInt16(20)
            output.appendUInt16(0x0800)
            output.appendUInt16(0)
            output.appendUInt16(0)
            output.appendUInt16(0x0021)
            output.appendUInt32(crc)
            output.appendUInt32(size)
            output.appendUInt32(size)
            output.appendUInt16(UInt16(nameData.count))
            output.appendUInt16(0)
            output.append(nameData)
            output.append(content)

            entries.append(Entry(name: name, crc: crc, size: size, localOffset: offset))
        }

        let centralOffset = UInt32(output.count)
        var central = Data()
        for entry in entries {
            let name = Data(entry.name.utf8)
            central.appendUInt32(0x02014b50)
            central.appendUInt16(20)
            central.appendUInt16(20)
            central.appendUInt16(0x0800)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt16(0x0021)
            central.appendUInt32(entry.crc)
            central.appendUInt32(entry.size)
            central.appendUInt32(entry.size)
            central.appendUInt16(UInt16(name.count))
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt16(0)
            central.appendUInt32(0)
            central.appendUInt32(entry.localOffset)
            central.append(name)
        }

        guard central.count <= Int(UInt32.max) else { throw ArchiveTransferError.archiveTooLarge }
        output.append(central)
        output.appendUInt32(0x06054b50)
        output.appendUInt16(0)
        output.appendUInt16(0)
        output.appendUInt16(UInt16(entries.count))
        output.appendUInt16(UInt16(entries.count))
        output.appendUInt32(UInt32(central.count))
        output.appendUInt32(centralOffset)
        output.appendUInt16(0)
        return output
    }

    static func extract(_ archive: Data, maximumTotalBytes: Int) throws -> [String: Data] {
        guard archive.count >= 22, archive.count <= maximumTotalBytes else {
            throw ArchiveTransferError.invalidPackage("Tệp archive không hợp lệ hoặc quá lớn.")
        }

        let lowerBound = max(0, archive.count - 65_557)
        var endOffset: Int?
        if archive.count >= 22 {
            for offset in stride(from: archive.count - 22, through: lowerBound, by: -1) {
                if archive.readUInt32(at: offset) == 0x06054b50 {
                    endOffset = offset
                    break
                }
            }
        }
        guard let end = endOffset else {
            throw ArchiveTransferError.invalidPackage("Không tìm thấy cấu trúc kết thúc ZIP.")
        }

        let count = Int(archive.readUInt16(at: end + 10))
        let centralSize = Int(archive.readUInt32(at: end + 12))
        let centralOffset = Int(archive.readUInt32(at: end + 16))
        guard count <= 65_535,
              centralOffset >= 0,
              centralSize >= 0,
              centralOffset <= archive.count,
              centralSize <= archive.count - centralOffset,
              centralOffset + centralSize <= end else {
            throw ArchiveTransferError.invalidPackage("Bảng chỉ mục ZIP không hợp lệ.")
        }

        var result: [String: Data] = [:]
        var cursor = centralOffset
        var totalBytes = 0

        for _ in 0..<count {
            guard cursor + 46 <= archive.count,
                  archive.readUInt32(at: cursor) == 0x02014b50 else {
                throw ArchiveTransferError.invalidPackage("Mục trong bảng chỉ mục ZIP bị hỏng.")
            }

            let flags = archive.readUInt16(at: cursor + 8)
            let method = archive.readUInt16(at: cursor + 10)
            let crc = archive.readUInt32(at: cursor + 16)
            let compressedSize = Int(archive.readUInt32(at: cursor + 20))
            let uncompressedSize = Int(archive.readUInt32(at: cursor + 24))
            let nameLength = Int(archive.readUInt16(at: cursor + 28))
            let extraLength = Int(archive.readUInt16(at: cursor + 30))
            let commentLength = Int(archive.readUInt16(at: cursor + 32))
            let localOffset = Int(archive.readUInt32(at: cursor + 42))
            let recordLength = 46 + nameLength + extraLength + commentLength

            guard cursor + recordLength <= archive.count,
                  flags == 0x0800,
                  method == 0,
                  compressedSize == uncompressedSize,
                  uncompressedSize <= maximumTotalBytes,
                  nameLength > 0 else {
                throw ArchiveTransferError.invalidPackage("Archive sử dụng định dạng nén hoặc cờ không được hỗ trợ.")
            }

            let nameData = archive.subdata(in: (cursor + 46)..<(cursor + 46 + nameLength))
            guard let name = String(data: nameData, encoding: .utf8),
                  isSafeArchivePath(name),
                  result[name] == nil else {
                throw ArchiveTransferError.unsafePath
            }

            guard localOffset + 30 <= archive.count,
                  archive.readUInt32(at: localOffset) == 0x04034b50 else {
                throw ArchiveTransferError.invalidPackage("Header của tệp đính kèm không hợp lệ.")
            }
            let localNameLength = Int(archive.readUInt16(at: localOffset + 26))
            let localExtraLength = Int(archive.readUInt16(at: localOffset + 28))
            let contentOffset = localOffset + 30 + localNameLength + localExtraLength
            guard contentOffset >= 0,
                  contentOffset <= archive.count,
                  compressedSize <= archive.count - contentOffset else {
                throw ArchiveTransferError.invalidPackage("Dữ liệu tệp đính kèm bị cắt cụt.")
            }

            let content = archive.subdata(in: contentOffset..<(contentOffset + compressedSize))
            guard crc32(content) == crc else {
                throw ArchiveTransferError.checksumMismatch(name)
            }

            totalBytes += content.count
            guard totalBytes <= maximumTotalBytes else { throw ArchiveTransferError.archiveTooLarge }
            result[name] = content
            cursor += recordLength
        }

        guard cursor == centralOffset + centralSize else {
            throw ArchiveTransferError.invalidPackage("Kích thước bảng chỉ mục ZIP không khớp.")
        }
        return result
    }

    private static func isSafeArchivePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\") else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8(value & 0x00FF))
        append(UInt8((value >> 8) & 0x00FF))
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(UInt8(value & 0x000000FF))
        append(UInt8((value >> 8) & 0x000000FF))
        append(UInt8((value >> 16) & 0x000000FF))
        append(UInt8((value >> 24) & 0x000000FF))
    }

    func readUInt16(at offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func readUInt32(at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= count else { return 0 }
        return UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
}
