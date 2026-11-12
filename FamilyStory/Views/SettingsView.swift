import SwiftUI

struct SettingsView: View {
    var body: some View {
        ArchivePage(title: "Kho lưu trữ", eyebrow: "Bảo quản ký ức") {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ký ức của bạn được lưu trên thiết bị.")
                        .font(.system(size: 18, design: .serif))
                        .foregroundStyle(FamilyPalette.ink)
                    Text("Family Story không vận hành máy chủ lưu trữ hay gửi bản ghi đến dịch vụ AI bên ngoài trong phiên bản này.")
                        .font(.system(size: 13))
                        .lineSpacing(4)
                        .foregroundStyle(FamilyPalette.sepia)
                }
                .padding(18)
                .background(FamilyPalette.linen, in: RoundedRectangle(cornerRadius: 18))

                Label("Không cần tài khoản", systemImage: "person.crop.circle.badge.check")
                Label("Ghi âm và dữ liệu lưu cục bộ", systemImage: "internaldrive")
                Label("Không yêu cầu kết nối Internet", systemImage: "wifi.slash")
                Divider().overlay(FamilyPalette.rule)
                Text("Lưu ý về sao lưu")
                    .font(.system(size: 19, design: .serif))
                    .foregroundStyle(FamilyPalette.ink)
                Text("Cài đặt sao lưu của iOS có thể bao gồm dữ liệu ứng dụng. Khi bạn xuất hoặc chia sẻ tệp, bản sao sẽ được lưu tại nơi nhận do bạn chọn. Hãy chủ động giữ một bản sao lưu an toàn.")
                    .font(.system(size: 12))
                    .lineSpacing(4)
                    .foregroundStyle(FamilyPalette.sepia)
            }
            .font(.system(size: 14))
            .foregroundStyle(FamilyPalette.ink)
        }
    }
}