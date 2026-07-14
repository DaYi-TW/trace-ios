import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject private var appLock: AppLockManager

    var body: some View {
        NavigationStack {
            List {
                Section("目前版本的資料原則") {
                    Label("附件與事件資料保留在這台裝置。", systemImage: "iphone")
                    Label("不讀取 LINE 或其他聊天 App 的帳號與對話資料。", systemImage: "hand.raised")
                    Label("OCR 僅產生待確認文字，不會覆蓋原始截圖。", systemImage: "text.viewfinder")
                    Label("不判定是否構成職場霸凌。", systemImage: "scale.3d")
                }
                Section("開啟保護") {
                    Toggle("使用 Face ID／裝置密碼解鎖", isOn: $appLock.isEnabled)
                    Text("離開 App 進入背景後，留痕會要求重新解鎖。這是畫面存取保護；資料檔案仍依 iOS Data Protection 保存。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("備份與還原") {
                    NavigationLink("建立或還原加密備份") {
                        BackupView()
                    }
                    Text("備份密碼不會保存。若遺失密碼，備份無法還原。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("測試版提醒") {
                    Text("請勿在未確認資料保護、備份與還原流程前，僅保留唯一一份重要原始資料。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("資料與隱私")
        }
    }
}
