import SwiftUI
import SwiftData

struct RecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @StateObject private var recorder = AudioRecorderService()

    @State private var title = ""
    @State private var notes = ""
    @State private var eventDate = Date.now
    @State private var hasEventDate = false
    @State private var selectedPersonIDs: Set<UUID> = []
    @State private var recordingFinished = false
    @State private var savedToArchive = false
    @State private var showDiscardConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                FamilyPalette.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        Text(recorder.isRecording ? (recorder.isPaused ? "Đang tạm dừng" : "Đang lắng nghe") : "Một câu chuyện đáng nhớ")
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(FamilyPalette.sepia)
                            .padding(.top, 16)

                        ZStack {
                            Circle().stroke(FamilyPalette.rule, lineWidth: 1).frame(width: 210, height: 210)
                            Circle().fill(FamilyPalette.clay.opacity(0.10)).frame(width: 174, height: 174)
                            Image(systemName: recorder.isRecording ? "waveform" : "mic")
                                .font(.system(size: 54, weight: .ultraLight))
                                .foregroundStyle(recorder.isRecording ? FamilyPalette.clay : FamilyPalette.olive)
                        }

                        Text(timeLabel(recorder.elapsed))
                            .font(.system(size: 40, weight: .light, design: .monospaced))
                            .foregroundStyle(FamilyPalette.ink)

                        HStack(spacing: 30) {
                            if recorder.isRecording {
                                Button {
                                    recorder.isPaused ? recorder.resume() : recorder.pause()
                                } label: {
                                    Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                                        .font(.system(size: 20))
                                        .frame(width: 58, height: 58)
                                        .background(FamilyPalette.linen, in: Circle())
                                }
                                .accessibilityLabel(recorder.isPaused ? "Tiếp tục ghi âm" : "Tạm dừng ghi âm")

                                Button {
                                    if recorder.finish() != nil { recordingFinished = true }
                                } label: {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white)
                                        .frame(width: 72, height: 72)
                                        .background(FamilyPalette.clay, in: Circle())
                                }
                                .accessibilityLabel("Kết thúc ghi âm")
                            } else if !recordingFinished {
                                Button {
                                    Task { await recorder.requestPermissionAndStart() }
                                } label: {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(.white)
                                        .frame(width: 76, height: 76)
                                        .background(FamilyPalette.olive, in: Circle())
                                }
                                .accessibilityLabel("Bắt đầu ghi âm")
                            } else {
                                Label("Bản ghi đã hoàn tất", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(FamilyPalette.olive)
                            }
                        }

                        if recordingFinished, let url = recorder.savedURL {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Hoàn thiện câu chuyện")
                                    .font(.system(size: 22, design: .serif))
                                    .foregroundStyle(FamilyPalette.ink)

                                TextField("Đặt tên câu chuyện", text: $title)
                                    .font(.system(size: 16, design: .serif))
                                    .padding(13)
                                    .background(FamilyPalette.card, in: RoundedRectangle(cornerRadius: 12))

                                TextField("Ghi chú (không bắt buộc)", text: $notes, axis: .vertical)
                                    .lineLimit(3...6)
                                    .padding(13)
                                    .background(FamilyPalette.card, in: RoundedRectangle(cornerRadius: 12))

                                Toggle("Có ngày sự kiện riêng", isOn: $hasEventDate).tint(FamilyPalette.olive)
                                if hasEventDate {
                                    DatePicker("Ngày diễn ra", selection: $eventDate, displayedComponents: .date)
                                }

                                if !people.isEmpty {
                                    VStack(alignment: .leading, spacing: 9) {
                                        Text("Ai xuất hiện trong câu chuyện?")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(FamilyPalette.sepia)
                                        ForEach(people) { person in
                                            Button {
                                                if selectedPersonIDs.contains(person.id) {
                                                    selectedPersonIDs.remove(person.id)
                                                } else {
                                                    selectedPersonIDs.insert(person.id)
                                                }
                                            } label: {
                                                HStack {
                                                    Image(systemName: selectedPersonIDs.contains(person.id) ? "checkmark.circle.fill" : "circle")
                                                        .foregroundStyle(FamilyPalette.olive)
                                                    Text(person.name).foregroundStyle(FamilyPalette.ink)
                                                    if !person.relationship.isEmpty {
                                                        Text("· \(person.relationship)").foregroundStyle(FamilyPalette.sepia)
                                                    }
                                                    Spacer()
                                                }
                                                .font(.system(size: 13))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(14)
                                    .background(FamilyPalette.linen.opacity(0.65), in: RoundedRectangle(cornerRadius: 13))
                                }

                                Button {
                                    let linkedPeople = people.filter { selectedPersonIDs.contains($0.id) }
                                    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let memory = Memory(
                                        title: cleanTitle.isEmpty ? "Câu chuyện mới" : cleanTitle,
                                        notes: notes,
                                        recordedAt: .now,
                                        eventDate: hasEventDate ? eventDate : nil,
                                        audioFilename: url.lastPathComponent,
                                        duration: recorder.elapsed,
                                        people: linkedPeople
                                    )
                                    context.insert(memory)
                                    do {
                                        try context.save()
                                        savedToArchive = true
                                        dismiss()
                                    } catch {
                                        context.rollback()
                                        recorder.errorMessage = "Không thể lưu thông tin câu chuyện: \(error.localizedDescription)"
                                    }
                                } label: {
                                    Text("Lưu vào kho ký ức")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(15)
                                        .background(FamilyPalette.olive, in: RoundedRectangle(cornerRadius: 14))
                                }
                            }
                            .padding(18)
                            .background(FamilyPalette.card, in: RoundedRectangle(cornerRadius: 18))
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(22)
                }
            }
            .navigationTitle("Ghi âm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") {
                        if recorder.isRecording || recordingFinished {
                            showDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundStyle(FamilyPalette.sepia)
                }
            }
            .confirmationDialog("Rời màn hình ghi âm?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("Xóa bản ghi và đóng", role: .destructive) {
                    if !savedToArchive { recorder.discard() }
                    dismiss()
                }
                Button("Tiếp tục ở lại", role: .cancel) {}
            } message: {
                Text("Bản ghi chưa lưu sẽ bị xóa khỏi thiết bị.")
            }
            .alert("Có lỗi xảy ra", isPresented: Binding(
                get: { recorder.errorMessage != nil },
                set: { if !$0 { recorder.errorMessage = nil } }
            )) {
                Button("Đã hiểu", role: .cancel) { recorder.errorMessage = nil }
            } message: {
                Text(recorder.errorMessage ?? "")
            }
            .onDisappear {
                if !savedToArchive, recorder.savedURL != nil { recorder.discard() }
            }
        }
    }
}
