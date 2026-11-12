import SwiftUI
import SwiftData

struct PeopleView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @State private var showingAdd = false
    @State private var personToDelete: Person?

    var body: some View {
        ArchivePage(title: "Những người thân", eyebrow: "Gia đình") {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeading(title: "Người trong câu chuyện", trailing: "\(people.count) hồ sơ")
                if people.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.2")
                            .font(.system(size: 28, weight: .ultraLight))
                            .foregroundStyle(FamilyPalette.olive)
                        Text("Gia đình bắt đầu từ những cái tên thân quen.")
                            .font(.system(size: 15, design: .serif))
                            .foregroundStyle(FamilyPalette.sepia)
                            .multilineTextAlignment(.center)
                        Text("Thêm người thân để kết nối họ với những câu chuyện.")
                            .font(.system(size: 12))
                            .foregroundStyle(FamilyPalette.sepia)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 35)
                } else {
                    ForEach(people) { person in
                        NavigationLink {
                            PersonDetailView(person: person)
                        } label: {
                            HStack(spacing: 13) {
                                Circle()
                                    .fill(FamilyPalette.linen)
                                    .frame(width: 48, height: 48)
                                    .overlay(Image(systemName: "person.fill").foregroundStyle(FamilyPalette.olive))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(person.name)
                                        .font(.system(size: 16, design: .serif))
                                        .foregroundStyle(FamilyPalette.ink)
                                    Text(person.relationship.isEmpty ? "Thành viên gia đình" : person.relationship)
                                        .font(.system(size: 11))
                                        .foregroundStyle(FamilyPalette.sepia)
                                }
                                Spacer()
                                Text("\(person.memories.count) ký ức")
                                    .font(.system(size: 10))
                                    .foregroundStyle(FamilyPalette.sepia)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundStyle(FamilyPalette.sepia)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { personToDelete = person } label: {
                                Label("Xóa hồ sơ", systemImage: "trash")
                            }
                        }
                    }
                }

                Button { showingAdd = true } label: {
                    Label("Thêm người thân", systemImage: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FamilyPalette.olive)
                        .padding(.vertical, 10)
                }
            }
        }
        .sheet(isPresented: $showingAdd) { AddPersonView() }
        .confirmationDialog(
            "Xóa hồ sơ người thân?",
            isPresented: Binding(
                get: { personToDelete != nil },
                set: { if !$0 { personToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Xóa hồ sơ", role: .destructive) {
                guard let personToDelete else { return }
                context.delete(personToDelete)
                do { try context.save() } catch { context.rollback() }
                self.personToDelete = nil
            }
            Button("Hủy", role: .cancel) { personToDelete = nil }
        } message: {
            Text("Các câu chuyện đã liên kết vẫn được giữ lại; chỉ hồ sơ người thân này bị xóa.")
        }
    }
}

struct AddPersonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var relationship = ""
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin") {
                    TextField("Tên người thân", text: $name)
                    TextField("Mối quan hệ (ví dụ: Bà ngoại)", text: $relationship)
                    TextField("Ghi chú (không bắt buộc)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Thêm người thân")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        let person = Person(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            relationship: relationship,
                            notes: notes
                        )
                        context.insert(person)
                        do {
                            try context.save()
                            dismiss()
                        } catch {
                            context.rollback()
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Không thể lưu", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("Đóng", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

struct PersonDetailView: View {
    @Bindable var person: Person

    var body: some View {
        ArchivePage(title: person.name, eyebrow: person.relationship.isEmpty ? "Người thân" : person.relationship) {
            if !person.notes.isEmpty {
                Text(person.notes)
                    .font(.system(size: 15, design: .serif))
                    .lineSpacing(4)
                    .foregroundStyle(FamilyPalette.sepia)
            }
            SectionHeading(title: "Những câu chuyện", trailing: "\(person.memories.count)")
            if person.memories.isEmpty {
                Text("Chưa có câu chuyện nào được gắn với \(person.name).")
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(FamilyPalette.sepia)
                    .padding(.vertical, 20)
            } else {
                ForEach(person.memories.sorted { $0.recordedAt > $1.recordedAt }) { memory in
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
