import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct MemoryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var memory: Memory

    @StateObject private var player = AudioPlaybackService()
    @State private var editing = false
    @State private var showingDeleteConfirmation = false
    @State private var isTranscribing = false
    @State private var transcriptionError: String?
    @State private var transcriber = TranscriptionService()

    var body: some View {
        ArchivePage(title: memory.title, eyebrow: "Ký ức gia đình") {
            VStack(alignment: .leading, spacing: 20) {
                if let filename = memory.photoFilename,
                   let image = UIImage(contentsOfFile: ArchiveStorage.photoURL(filename: filename).path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                if let filename = memory.audioFilename {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "waveform")
                                .font(.system(size: 24))
                                .foregroundStyle(FamilyPalette.olive)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Bản ghi gốc")
                                    .font(.system(size: 15, weight: .medium, design: .serif))
                                Text(timeLabel(memory.duration))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(FamilyPalette.sepia)
                            }
                            Spacer()
                            Button {
                                player.toggle(url: ArchiveStorage.audioURL(filename: filename))
                            } label: {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .foregroundStyle(.white)
                                    .frame(width: 48, height: 48)
                                    .background(FamilyPalette.olive, in: Circle())
                            }
                            .accessibilityLabel(player.isPlaying ? "Tạm dừng" : "Phát bản ghi")
                        }
                        if player.duration > 0 {
                            Slider(
                                value: Binding(
                                    get: { player.currentTime },
                                    set: { player.seek(to: $0) }
                                ),
                                in: 0...max(player.duration, 0.1)
                            )
                            .tint(FamilyPalette.olive)
                            HStack {
                                Text(timeLabel(player.currentTime))
                                Spacer()
                                Text(timeLabel(player.duration))
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(FamilyPalette.sepia)
                        }
                    }
                    .padding(18)
                    .background(FamilyPalette.linen, in: RoundedRectangle(cornerRadius: 18))
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text(memory.eventDate == nil ? "Ngày ghi âm" : "Ngày sự kiện")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(FamilyPalette.sepia)
                    Text((memory.eventDate ?? memory.recordedAt).formatted(date: .long, time: .omitted))
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(FamilyPalette.ink)
                    if memory.eventDate != nil {
                        Text("Được ghi âm vào \(memory.recordedAt.formatted(date: .long, time: .omitted))")
                            .font(.system(size: 11))
                            .foregroundStyle(FamilyPalette.sepia)
                    }
                }

                if !memory.people.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Người thân")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.3)
                            .foregroundStyle(FamilyPalette.sepia)
                        ForEach(memory.people) { person in
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill").foregroundStyle(FamilyPalette.olive)
                                Text(person.name)
                                    .font(.system(size: 14, design: .serif))
                                    .foregroundStyle(FamilyPalette.ink)
                                if !person.relationship.isEmpty {
                                    Text("· \(person.relationship)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(FamilyPalette.sepia)
                                }
                            }
                        }
                    }
                }

                if !memory.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ghi chú")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.3)
                            .foregroundStyle(FamilyPalette.sepia)
                        Text(memory.notes)
                            .font(.system(size: 16, design: .serif))
                            .lineSpacing(5)
                            .foregroundStyle(FamilyPalette.ink)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Bản chép lời")
                            .font(.system(size: 21, design: .serif))
                            .foregroundStyle(FamilyPalette.ink)
                        Spacer()
                        if memory.transcript.isEmpty, memory.audioFilename != nil {
                            Button {
                                Task { await createTranscript() }
                            } label: {
                                if isTranscribing {
                                    ProgressView().tint(FamilyPalette.olive)
                                } else {
                                    Label("Chép lời", systemImage: "text.quote")
                                        .font(.system(size: 12, weight: .medium))
                                }
                            }
                            .disabled(isTranscribing)
                            .foregroundStyle(FamilyPalette.olive)
                        }
                    }
                    if memory.transcript.isEmpty {
                        Text("Bạn có thể tạo bản chép lời hoàn toàn trên thiết bị khi iPhone hỗ trợ tiếng Việt.")
                            .font(.system(size: 12))
                            .lineSpacing(4)
                            .foregroundStyle(FamilyPalette.sepia)
                    } else {
                        Text(memory.transcript)
                            .font(.system(size: 15, design: .serif))
                            .lineSpacing(5)
                            .foregroundStyle(FamilyPalette.ink)
                    }
                    Text("Bản chép tự động có thể sai. Hãy kiểm tra trước khi xem là nội dung đã xác nhận.")
                        .font(.system(size: 10))
                        .foregroundStyle(FamilyPalette.sepia)
                }
                .padding(16)
                .background(FamilyPalette.card, in: RoundedRectangle(cornerRadius: 16))

                Button("Chỉnh sửa câu chuyện") { editing = true }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FamilyPalette.olive)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Chỉnh sửa", systemImage: "pencil") { editing = true }
                    Button("Xóa câu chuyện", systemImage: "trash", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(FamilyPalette.sepia)
                }
            }
        }
        .sheet(isPresented: $editing) { EditMemoryView(memory: memory) }
        .confirmationDialog("Xóa câu chuyện này?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Xóa câu chuyện và tệp đính kèm", role: .destructive) { deleteMemory() }
            Button("Hủy", role: .cancel) {}
        } message: {
            Text("Bản ghi âm và ảnh đính kèm của câu chuyện này sẽ bị xóa khỏi kho lưu trữ trên thiết bị. Các bản sao đã xuất trước đó không bị ảnh hưởng.")
        }
        .alert("Không thể xử lý", isPresented: Binding(
            get: { transcriptionError != nil || player.errorMessage != nil },
            set: { if !$0 { transcriptionError = nil; player.errorMessage = nil } }
        )) {
            Button("Đóng", role: .cancel) {
                transcriptionError = nil
                player.errorMessage = nil
            }
        } message: {
            Text(transcriptionError ?? player.errorMessage ?? "")
        }
        .onDisappear {
            player.pause()
            transcriber.cancel()
        }
    }

    @MainActor
    private func createTranscript() async {
        guard let filename = memory.audioFilename else { return }
        isTranscribing = true
        defer { isTranscribing = false }
        do {
            let text = try await transcriber.transcribe(url: ArchiveStorage.audioURL(filename: filename))
            memory.transcript = text
            try context.save()
        } catch {
            transcriptionError = error.localizedDescription
        }
    }

    private func deleteMemory() {
        let audioURL = memory.audioFilename.map { ArchiveStorage.audioURL(filename: $0) }
        let photoURL = memory.photoFilename.map { ArchiveStorage.photoURL(filename: $0) }
        context.delete(memory)
        do {
            try context.save()
            if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
            if let photoURL { try? FileManager.default.removeItem(at: photoURL) }
            dismiss()
        } catch {
            context.rollback()
            transcriptionError = "Không thể xóa câu chuyện: \(error.localizedDescription)"
        }
    }
}

struct EditMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @Bindable var memory: Memory

    @State private var title: String
    @State private var notes: String
    @State private var transcript: String
    @State private var hasEventDate: Bool
    @State private var eventDate: Date
    @State private var selectedPersonIDs: Set<UUID>
    @State private var photoSelection: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoPreview: UIImage?
    @State private var removePhoto = false
    @State private var saveError: String?

    init(memory: Memory) {
        self.memory = memory
        _title = State(initialValue: memory.title)
        _notes = State(initialValue: memory.notes)
        _transcript = State(initialValue: memory.transcript)
        _hasEventDate = State(initialValue: memory.eventDate != nil)
        _eventDate = State(initialValue: memory.eventDate ?? memory.recordedAt)
        _selectedPersonIDs = State(initialValue: Set(memory.people.map(\.id)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Câu chuyện") {
                    TextField("Tiêu đề", text: $title)
                    TextField("Ghi chú", text: $notes, axis: .vertical).lineLimit(4...8)
                    Toggle("Có ngày sự kiện riêng", isOn: $hasEventDate)
                    if hasEventDate {
                        DatePicker("Ngày diễn ra", selection: $eventDate, displayedComponents: .date)
                    }
                }

                Section("Người thân") {
                    if people.isEmpty {
                        Text("Bạn chưa thêm hồ sơ người thân.").foregroundStyle(FamilyPalette.sepia)
                    } else {
                        ForEach(people) { person in
                            Button {
                                if selectedPersonIDs.contains(person.id) {
                                    selectedPersonIDs.remove(person.id)
                                } else {
                                    selectedPersonIDs.insert(person.id)
                                }
                            } label: {
                                HStack {
                                    Text(person.name).foregroundStyle(FamilyPalette.ink)
                                    Spacer()
                                    Image(systemName: selectedPersonIDs.contains(person.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(FamilyPalette.olive)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Ảnh kỷ niệm") {
                    if let photoPreview {
                        Image(uiImage: photoPreview)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                    } else if let filename = memory.photoFilename,
                              !removePhoto,
                              let image = UIImage(contentsOfFile: ArchiveStorage.photoURL(filename: filename).path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                    }

                    PhotosPicker(selection: $photoSelection, matching: .images) {
                        Label("Chọn ảnh từ thư viện", systemImage: "photo")
                    }
                    if memory.photoFilename != nil || photoPreview != nil {
                        Button("Gỡ ảnh khỏi câu chuyện", role: .destructive) {
                            removePhoto = true
                            photoPreview = nil
                            photoData = nil
                            photoSelection = nil
                        }
                    }
                    Text("Ảnh được sao chép vào kho lưu trữ cục bộ của Family Story.")
                        .font(.footnote)
                        .foregroundStyle(FamilyPalette.sepia)
                }

                Section("Bản chép lời") {
                    TextField("Nội dung bản chép lời", text: $transcript, axis: .vertical)
                        .lineLimit(5...12)
                    Text("Bản chép lời có thể chỉnh sửa; bản ghi âm gốc không bị thay đổi.")
                        .font(.footnote)
                        .foregroundStyle(FamilyPalette.sepia)
                }
            }
            .scrollContentBackground(.hidden)
            .background(FamilyPalette.paper)
            .navigationTitle("Chỉnh sửa")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { Task { await saveChanges() } }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: photoSelection) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data),
                          let jpeg = image.jpegData(compressionQuality: 0.86) else { return }
                    photoData = jpeg
                    photoPreview = UIImage(data: jpeg)
                    removePhoto = false
                }
            }
            .alert("Không thể lưu", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("Đóng", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    @MainActor
    private func saveChanges() async {
        let oldPhoto = memory.photoFilename
        var newPhotoFilename = oldPhoto

        do {
            if let photoData {
                try ArchiveStorage.prepareDirectories()
                let filename = "photo-\(UUID().uuidString).jpg"
                try photoData.write(to: ArchiveStorage.photoURL(filename: filename), options: .atomic)
                newPhotoFilename = filename
            } else if removePhoto {
                newPhotoFilename = nil
            }

            memory.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            memory.notes = notes
            memory.transcript = transcript
            memory.eventDate = hasEventDate ? eventDate : nil
            memory.people = people.filter { selectedPersonIDs.contains($0.id) }
            memory.photoFilename = newPhotoFilename
            try context.save()

            if let oldPhoto, oldPhoto != newPhotoFilename {
                try? FileManager.default.removeItem(at: ArchiveStorage.photoURL(filename: oldPhoto))
            }
            dismiss()
        } catch {
            context.rollback()
            if let newPhotoFilename, newPhotoFilename != oldPhoto {
                try? FileManager.default.removeItem(at: ArchiveStorage.photoURL(filename: newPhotoFilename))
            }
            saveError = error.localizedDescription
        }
    }
}
