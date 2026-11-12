import SwiftUI
import SwiftData

struct MemoryDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var memory: Memory
    @StateObject private var player = AudioPlaybackService()
    @State private var editing = false

    var body: some View {
        ArchivePage(title: memory.title, eyebrow: "Ký ức gia đình") {
            VStack(alignment: .leading, spacing: 20) {
                if let filename = memory.audioFilename {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "waveform").font(.system(size: 24)).foregroundStyle(FamilyPalette.olive)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Bản ghi gốc").font(.system(size: 15, weight: .medium, design: .serif))
                                Text(timeLabel(memory.duration)).font(.system(size: 11, design: .monospaced)).foregroundStyle(FamilyPalette.sepia)
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
                            Slider(value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }), in: 0...max(player.duration, 0.1))
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
                    Text("Ghi lại vào ngày").font(.system(size: 11, weight: .semibold)).tracking(1.3).foregroundStyle(FamilyPalette.sepia)
                    Text(memory.recordedAt.formatted(date: .long, time: .omitted))
                        .font(.system(size: 15, design: .serif)).foregroundStyle(FamilyPalette.ink)
                }
                if !memory.notes.isEmpty {
                    Text(memory.notes)
                        .font(.system(size: 16, design: .serif))
                        .lineSpacing(5)
                        .foregroundStyle(FamilyPalette.ink)
                }
                Button("Chỉnh sửa câu chuyện") { editing = true }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FamilyPalette.olive)
            }
        }
        .sheet(isPresented: $editing) {
            EditMemoryView(memory: memory)
        }
        .onDisappear { player.pause() }
    }
}

struct EditMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var memory: Memory
    @State private var title: String
    @State private var notes: String

    init(memory: Memory) {
        self.memory = memory
        _title = State(initialValue: memory.title)
        _notes = State(initialValue: memory.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Câu chuyện") {
                    TextField("Tiêu đề", text: $title)
                    TextField("Ghi chú", text: $notes, axis: .vertical).lineLimit(4...8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(FamilyPalette.paper)
            .navigationTitle("Chỉnh sửa")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        memory.title = title
                        memory.notes = notes
                        dismiss()
                    }
                }
            }
        }
    }
}