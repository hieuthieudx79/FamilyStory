import SwiftUI
import SwiftData

@main
struct FamilyStoryApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Memory.self, Person.self)
        } catch {
            fatalError("Unable to create local archive: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .tint(FamilyPalette.olive)
        }
    }
}