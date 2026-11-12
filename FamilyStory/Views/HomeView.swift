import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Memory.recordedAt, order: .reverse) private var memories: [Memory]
    @State private var showingRecorder = false
    @State private var searchText = ""

    private var filtered: [Memory] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return memories }
        return memories.filter { memory in
            memory.title.localizedCaseInsensitiveContains(query)
                || memory.notes.localizedCaseInsensitiveContains(query)
                || memory.transcript.localizedCaseInsensitiveContains(query)
                || memory.people.contains { $0.name.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        ArchivePage(title: "Những câu chuyện", eyebrow: "Kho lưu trữ gia đình") {
            VStack(alignment: .leading, spacing: 18) {
                Button { showingRecorder = true } label: {
                    HStack(spacing: 15) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 22))
                            .frame(width: 52, height: 52)
                            .background(.white.opacity(0.16), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ghi lại một câu chuyện")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Giữ lại giọng nói và khoảnh khắc")
                                .font(.system(size: 12))
                                .opacity(0.82)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(FamilyPalette.olive, in: RoundedRectangle(cornerRadius: 20))
                }
                .accessibilityHint("Mở màn hình ghi âm câu chuyện mới")

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(FamilyPalette.sepia)
                    TextField("Tìm câu chuyện, người thân, nội dung...", text: $searchText)
                        .font(.system(size: 14))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(FamilyPalette.sepia)
                        }
                        .accessibilityLabel("Xóa tìm kiếm")
                    }
                }
                .padding(14)
                .background(FamilyPalette.linen.opacity(0.7), in: RoundedRectangle(cornerRadius: 13))

                SectionHeading(title: "Dòng thời gian", trailing: "\(memories.count) câu chuyện")
                if filtered.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 30, weight: .ultraLight))
                            .foregroundStyle(FamilyPalette.olive)
                        Text(searchText.isEmpty ? "Câu chuyện đầu tiên đang chờ bạn." : "Không tìm thấy câu chuyện phù hợp.")
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(FamilyPalette.sepia)
                            .multilineTextAlignment(.center)
                        if searchText.isEmpty {
                            Text("Hãy bắt đầu bằng một giọng nói thân quen.")
                                .font(.system(size: 12))
                                .foregroundStyle(FamilyPalette.sepia)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 45)
                    .background(FamilyPalette.card, in: RoundedRectangle(cornerRadius: 18))
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { memory in
                            NavigationLink {
                                MemoryDetailView(memory: memory)
                            } label: {
                                MemoryRow(memory: memory)
                            }
                            .buttonStyle(.plain)
                            Divider().overlay(FamilyPalette.rule)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRecorder) { RecorderView() }
    }
}

struct MemoryRow: View {
    let memory: Memory

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 13)
                .fill(FamilyPalette.linen)
                .frame(width: 58, height: 58)
                .overlay(Image(systemName: "waveform").font(.system(size: 20)).foregroundStyle(FamilyPalette.olive))
            VStack(alignment: .leading, spacing: 5) {
                Text(memory.title)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(FamilyPalette.ink)
                    .lineLimit(1)
                Text(memory.eventDate ?? memory.recordedAt, format: .dateTime.day().month(.abbreviated).year())
                    .font(.system(size: 11))
                    .foregroundStyle(FamilyPalette.sepia)
                if !memory.people.isEmpty {
                    Text(memory.people.map(\.name).joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(FamilyPalette.olive)
                        .lineLimit(1)
                } else if !memory.notes.isEmpty {
                    Text(memory.notes).font(.system(size: 12)).foregroundStyle(FamilyPalette.sepia).lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(FamilyPalette.sepia)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
