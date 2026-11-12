import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasCreatedArchive") private var hasCreatedArchive = false
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if !hasCreatedArchive {
                WelcomeView { hasCreatedArchive = true }
            } else {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem { Label("Ký ức", systemImage: "books.vertical") }
                        .tag(0)
                    PeopleView()
                        .tabItem { Label("Gia đình", systemImage: "person.2") }
                        .tag(1)
                    SettingsView()
                        .tabItem { Label("Lưu trữ", systemImage: "archivebox") }
                        .tag(2)
                }
                .tint(FamilyPalette.olive)
            }
        }
        .preferredColorScheme(.light)
    }
}

struct WelcomeView: View {
    let onCreate: () -> Void

    var body: some View {
        ZStack {
            FamilyPalette.paper.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundStyle(FamilyPalette.olive)
                    .padding(28)
                    .overlay(Circle().stroke(FamilyPalette.rule, lineWidth: 1))
                Text("Family Story")
                    .font(.system(size: 42, weight: .regular, design: .serif))
                    .foregroundStyle(FamilyPalette.ink)
                Text("Keep Their Voices Forever.")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundStyle(FamilyPalette.sepia)
                Text("Mỗi giọng nói là một phần ký ức đáng được gìn giữ.")
                    .font(.system(size: 15))
                    .foregroundStyle(FamilyPalette.sepia)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Spacer()
                VStack(spacing: 14) {
                    Button(action: onCreate) {
                        Text("Tạo kho lưu trữ gia đình")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(FamilyPalette.olive, in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }
                    Text("Không cần tài khoản · Lưu trên thiết bị")
                        .font(.system(size: 11))
                        .foregroundStyle(FamilyPalette.sepia)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 35)
            }
        }
    }
}