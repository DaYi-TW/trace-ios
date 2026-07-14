import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject private var appLock: AppLockManager

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("你的紀錄，\n只在你手上。")
                            .font(TraceTheme.titleFont(31))
                            .foregroundStyle(.white)
                        Text("保留原始截圖、你的補充與可確認的事件時間線。")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .padding(.vertical, 16)
                    .listRowBackground(TraceTheme.vault)
                }
                Section("資料原則") {
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
            .scrollContentBackground(.hidden)
            .background(TraceTheme.vault)
            .foregroundStyle(.white)
            .tint(Color(red: 0.72, green: 0.86, blue: 0.73))
            .preferredColorScheme(.dark)
            .navigationTitle("保護")
            .toolbarBackground(TraceTheme.vault, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
