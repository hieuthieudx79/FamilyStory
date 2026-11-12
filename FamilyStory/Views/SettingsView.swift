import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Memory.recordedAt, order: .reverse) private var memories: [Memory]
    @Query(sort: \Person.name) private var people: [Person]
    @AppStorage("hasCreatedArchive") private var hasCreatedArchive = true

    @State private var exportDocument = FamilyArchiveDocument()
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingDeleteConfirmation = false
    @State private var showingImportConfirmation = false
    @State private var pendingArchive: ValidatedFamilyArchive?
    @State private var shareURL: URL?
    @State private var alertMessage: String?

    var body: some View {
        ArchivePage(title: "Kho lưu trữ", eyebrow: "Bảo quản ký ức") {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ký ức của bạn được lưu trên thiết bị.")
                        .font(.system(size: 18, design: .serif))
                        .foregroundStyle(FamilyPalette.ink)
                    Text("Family Story không vận hành máy chủ lưu trữ hay gửi bản ghi đến dịch vụ AI bên ngoài trong phiên bản này.")
                        .font(.system(size: 13))
                        .lineSpacing(4)
                        .foregroundStyle(FamilyPalette.sepia)
                }
                .padding(18)
                .background(FamilyPalette.linen, in: RoundedRectangle(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 12) {
                    Label("Không cần tài khoản", systemImage: "person.crop.circle.badge.check")
                    Label("Ghi âm và dữ liệu lưu cục bộ", systemImage: "internaldrive")
                    Label("Không yêu cầu kết nối Internet", systemImage: "wifi.slash")
                }
                .font(.system(size: 14))
                .foregroundStyle(FamilyPalette.ink)

                Divider().overlay(FamilyPalette.rule)

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading(title: "Dung lượng kho lưu trữ")
                    HStack {
                        Label("\(memories.count) câu chuyện", systemImage: "waveform")
                        Spacer()
                        Text(ArchiveStorage.formattedSize(ArchiveStorage.storageUsage()))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(FamilyPalette.sepia)
                    Text("\(people.count) hồ sơ người thân · Âm thanh và ảnh chiếm dung lượng bộ nhớ iPhone.")
                        .font(.system(size: 11))
                        .foregroundStyle(FamilyPalette.sepia)
                }

                Divider().overlay(FamilyPalette.rule)

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(title: "Sao lưu và chuyển kho")
                    Text("Tạo archive có manifest, thông tin câu chuyện, hồ sơ người thân và tệp âm thanh/ảnh. Mỗi tệp được kiểm tra checksum SHA-256 khi nhập.")
                        .font(.system(size: 12))
                        .lineSpacing(4)
                        .foregroundStyle(FamilyPalette.sepia)

                    Button { createArchiveForExport() } label: {
                        Label("Xuất toàn bộ kho lưu trữ", systemImage: "square.and.arrow.down")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(FamilyPalette.card, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .foregroundStyle(FamilyPalette.olive)

                    if let shareURL {
                        ShareLink(item: shareURL) {
                            Label("Chia sẻ archive qua iOS", systemImage: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(FamilyPalette.card, in: RoundedRectangle(cornerRadius: 13))
                        }
                        .foregroundStyle(FamilyPalette.olive)
                    }

                    Button { showingImporter = true } label: {
                        Label("Nhập archive từ Files", systemImage: "square.and.arrow.down.on.square")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(FamilyPalette.card, in: RoundedRectangle(cornerRadius: 13))
                    }
                    .foregroundStyle(FamilyPalette.olive)
                }

                Divider().overlay(FamilyPalette.rule)

                VStack(alignment: .leading, spacing: 9) {
                    Text("Lưu ý về sao lưu")
                        .font(.system(size: 19, design: .serif))
                        .foregroundStyle(FamilyPalette.ink)
                    Text("Cài đặt sao lưu của iOS có thể bao gồm dữ liệu ứng dụng. Khi bạn xuất hoặc chia sẻ tệp, bản sao sẽ được lưu tại nơi nhận do bạn chọn. Family Story không thể xóa những bản sao đó.")
                        .font(.system(size: 12))
                        .lineSpacing(4)
                        .foregroundStyle(FamilyPalette.sepia)
                }

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Xóa toàn bộ kho trên thiết bị", systemImage: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                }
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .familyStoryArchive,
            defaultFilename: "FamilyStory-Archive"
        ) { result in
            switch result {
            case .success:
                alertMessage = "Archive đã được xuất. Hãy lưu thêm một bản sao ở nơi an toàn."
            case .failure(let error):
                alertMessage = "Không thể xuất archive: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.familyStoryArchive],
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result)
        }
        .confirmationDialog("Xóa toàn bộ kho lưu trữ?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Xóa tất cả dữ liệu trên iPhone", role: .destructive) { deleteEntireArchive() }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Mọi câu chuyện, hồ sơ người thân, bản ghi âm và ảnh trong Family Story trên thiết bị này sẽ bị xóa. Các bản sao đã xuất hoặc được iOS sao lưu không bị xóa.")
        }
        .alert("Xác nhận nhập archive", isPresented: $showingImportConfirmation) {
            Button("Nhập vào kho", role: .destructive) { importPendingArchive() }
            Button("Hủy", role: .cancel) { pendingArchive = nil }
        } message: {
            if let pendingArchive {
                Text("Archive gồm \(pendingArchive.memoryCount) câu chuyện, \(pendingArchive.peopleCount) hồ sơ, \(pendingArchive.audioCount) bản ghi âm và \(pendingArchive.photoCount) ảnh. Các ID đã tồn tại sẽ được bỏ qua; dữ liệu hiện tại không bị ghi đè.")
            } else {
                Text("Không có archive chờ nhập.")
            }
        }
        .alert("Family Story", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("Đóng", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func createArchiveForExport() {
        do {
            let data = try ArchiveTransferService.makeArchive(memories: memories, people: people)
            exportDocument = FamilyArchiveDocument(data: data)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("FamilyStory-Archive-\(UUID().uuidString).familyarchive")
            try data.write(to: url, options: .atomic)
            shareURL = url
            showingExporter = true
        } catch {
            alertMessage = "Không thể tạo archive: \(error.localizedDescription)"
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess { url.stopAccessingSecurityScopedResource() }
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            pendingArchive = try ArchiveTransferService.validateArchive(data)
            showingImportConfirmation = true
        } catch {
            alertMessage = "Không thể đọc archive: \(error.localizedDescription)"
        }
    }

    private func importPendingArchive() {
        guard let pendingArchive else { return }
        do {
            let result = try ArchiveTransferService.importArchive(pendingArchive, into: context)
            alertMessage = "Đã nhập \(result.importedMemories) câu chuyện và \(result.importedPeople) hồ sơ. Bỏ qua \(result.skippedMemories) câu chuyện đã tồn tại."
            self.pendingArchive = nil
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func deleteEntireArchive() {
        let files = memories.flatMap { memory -> [URL] in
            var urls: [URL] = []
            if let audio = memory.audioFilename { urls.append(ArchiveStorage.audioURL(filename: audio)) }
            if let photo = memory.photoFilename { urls.append(ArchiveStorage.photoURL(filename: photo)) }
            return urls
        }

        do {
            for memory in memories { context.delete(memory) }
            for person in people { context.delete(person) }
            try context.save()
            for url in files { try? FileManager.default.removeItem(at: url) }
            try? FileManager.default.removeItem(at: ArchiveStorage.rootDirectory)
            hasCreatedArchive = false
        } catch {
            context.rollback()
            alertMessage = "Không thể xóa kho lưu trữ: \(error.localizedDescription)"
        }
    }
}
