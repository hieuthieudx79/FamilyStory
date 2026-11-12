import SwiftUI
import SwiftData

struct PeopleView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \\Person.name) private var people: [Person]
    @State private var showingAdd = false

    var body: some View {
        ArchivePage(title: "Những người thân", eyebrow: "Gia đình") {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeading(title: "Người trong câu chuyện")
                if people.isEmpty {
                    Text("Thêm người thân để gắn những câu chuyện với họ.")
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(FamilyPalette.sepia)
                        .padding(.vertical, 30)
                } else {
                    ForEach(people) { person in
                        HStack(spacing: 13) {
                            Circle().fill(FamilyPalette.linen).frame(width: 48, height: 48)
                                .overlay(Image(systemName: "person.fill").foregroundStyle(FamilyPalette.olive))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(person.name).font(.system(size: 16, design: .serif)).foregroundStyle(FamilyPalette.ink)
                                Text(person.relationship.isEmpty ? "Thành viên gia đình" : person.relationship)
                                    .font(.system(size: 11)).foregroundStyle(FamilyPalette.sepia)
                            }
                            Spacer()
                            Text("\(person.memories.count) ký ức").font(.system(size: 10)).foregroundStyle(FamilyPalette.sepia)
                        }
                        .padding(.vertical, 8)
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
    }
}

struct AddPersonView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var relationship = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin") {
                    TextField("Tên người thân", text: $name)
                    TextField("Mối quan hệ (ví dụ: Bà ngoại)", text: $relationship)
                }
            }
            .navigationTitle("Thêm người thân")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Hủy") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        context.insert(Person(name: name.trimmingCharacters(in: .whitespacesAndNewlines), relationship: relationship))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}