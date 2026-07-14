import SwiftUI

struct PrivacyView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("目前版本的資料原則") {
                    Label("附件與事件資料保留在這台裝置。", systemImage: "iphone")
                    Label("不讀取 LINE 或其他聊天 App 的帳號與對話資料。", systemImage: "hand.raised")
                    Label("OCR 僅產生待確認文字，不會覆蓋原始截圖。", systemImage: "text.viewfinder")
                    Label("不判定是否構成職場霸凌。", systemImage: "scale.3d")
                }
                Section("測試版提醒") {
                    Text("此版本尚未包含 Face ID、加密備份或完整還原。請勿在未確認資料保護與備份流程前，僅保留唯一一份重要原始資料。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("資料與隱私")
        }
    }
}
