import SwiftUI

enum FamilyPalette {
    static let paper = Color(hex: 0xF4F0E7)
    static let linen = Color(hex: 0xE8E0D2)
    static let card = Color(hex: 0xFBF9F4)
    static let ink = Color(hex: 0x302C27)
    static let sepia = Color(hex: 0x786957)
    static let olive = Color(hex: 0x74765A)
    static let clay = Color(hex: 0xA66F58)
    static let rule = Color(hex: 0xD8CFC1)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct ArchivePage<Content: View>: View {
    let title: String
    let eyebrow: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(2.2)
                        .foregroundStyle(FamilyPalette.sepia)
                    Text(title)
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .foregroundStyle(FamilyPalette.ink)
                }
                content
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(FamilyPalette.paper.ignoresSafeArea())
    }
}

struct SectionHeading: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 21, weight: .regular, design: .serif))
                .foregroundStyle(FamilyPalette.ink)
            Spacer()
            if let trailing {
                Text(trailing.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(FamilyPalette.sepia)
            }
        }
    }
}