import SwiftUI
import SwiftData

struct RecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @StateObject private var recorder = AudioRecorderService()
    @State private var title = ""
    @State private var notes = ""
    @State private var saved = false
    @State private var showDiscardConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                FamilyPalette.paper.ignoresSafeArea()
                VStack(spacing: 24) {
                    Spacer()
                    Text(recorder.isRecording ? (recorder.isPaused ? "Đang tạm dừng" : "Đang lắng nghe") : "Một câu chuyện đáng nhớ")
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(FamilyPalette.sepia)
                    ZStack {
                        Circle().stroke(FamilyPalette.rule, lineWidth: 1).frame(width: 220, height: 220)
                        Circle().fill(FamilyPalette.clay.opacity(0.10)).frame(width: 180, height: 180)
                        Image(systemName: recorder.isRecording ? "waveform" : "mic")
                            .font(.system(size: 54, weight: .ultraLight))
                            .foregroundStyle(recorder.isRecording ? FamilyPalette.clay : FamilyPalette.olive)
                    }
                    Text(timeLabel(recorder.elapsed))
                        .font(.system(size: 40, weight: .light, design: .monospaced))
                        .foregroundStyle(FamilyPalette.ink)
                    HStack(spacing: 30) {
                        if recorder.isRecording {
                            Button { recorder.isPaused ? recorder.resume() : recorder.pause() } label: {
                                Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 20))
                                    .frame(width: 58, height: 58)
                                    .background(FamilyPalette.linen, in: Circle())
                            }
                            .accessibilityLabel(recorder.isPaused ? "Tiếp tục" : "Tạm dừng")
                            Button { _ = recorder.finish(); saved = true } label: {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                                    .frame(width: 74, height: 74)
                                    .background(FamilyPalette.clay, in: Circle())
                            }
                            .accessibilityLabel("Kết thúc ghi âm")
                        } else {
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
                        }
                    }
                    if saved, let url = recorder.savedURL {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Đặt tên câu chuyện", text: $title)
                                .font(.system(size: 17, design: .serif))
                                .padding(13)
                                .background(FamilyPalette.card, in: RoundedRectangle(cornerRadius: 12))
                            TextField("Ghi chú (không bắt buộc)", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .padding(13)
                                .background(FamilyPalette.card, in: RoundedRectangle(cornerRadius: 12))
                            Button {
                                let memory = Memory(title: title.isEmpty ? "Câu chuyện mới" : title,
                                                    notes: notes,
                                                    audioFilename: url.lastPathComponent,
                                                    duration: recorder.elapsed)
                                context.insert(memory)
                                do {
                                    try context.save()
                                    dismiss()
                                } catch {
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
                    }
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Ghi âm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") { showDiscardConfirmation = true }
                        .foregroundStyle(FamilyPalette.sepia)
                }
            }
            .confirmationDialog("Rời màn hình ghi âm?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("Xóa bản ghi", role: .destructive) { recorder.discard(); dismiss() }
                Button("Tiếp tục ở lại", role: .cancel) {}
            } message: {
                Text("Bản ghi chưa lưu sẽ bị xóa khỏi thiết bị.")
            }
            .alert("Có lỗi xảy ra", isPresented: Binding(
                get: { recorder.errorMessage != nil },
                set: { if !$0 { recorder.errorMessage = nil } }
            )) {
                Button("Đã hiểu", role: .cancel) { recorder.errorMessage = nil }
            } message: { Text(recorder.errorMessage ?? "") }
        }
    }
}