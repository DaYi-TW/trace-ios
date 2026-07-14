import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TraceEvent.updatedAt, order: .reverse) private var events: [TraceEvent]
    @State private var password = ""
    @State private var confirmation = ""
    @State private var backupURL: URL?
    @State private var showingRestoreImporter = false
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("建立加密備份") {
                SecureField("設定備份密碼", text: $password)
                SecureField("再次輸入密碼", text: $confirmation)
                Button("建立加密備份") { createBackup() }
                    .disabled(password.isEmpty || password != confirmation || events.isEmpty)
                Text("備份包含事件資料及目前已保存的原始附件。密碼不會寫入 App、iCloud 或備份檔。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("還原備份") {
                Button("選擇 .tracebackup 檔案") { showingRestoreImporter = true }
                Text("還原會新增事件與附件，不會覆蓋目前資料。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("加密備份")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showingRestoreImporter, allowedContentTypes: [.data]) { result in
            if case .success(let url) = result { restore(from: url) }
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
        .sheet(item: $backupURL) { url in
            ActivityView(items: [url])
        }
        .alert("備份完成", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好", role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
        .alert("無法完成備份", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func createBackup() {
        do {
            backupURL = try BackupService.createBackup(events: events, password: password)
            password = ""
            confirmation = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restore(from url: URL) {
        guard !password.isEmpty else {
            errorMessage = "請先在上方輸入此備份使用的密碼，再選擇備份檔案。"
            return
        }
        do {
            let count = try BackupService.restoreBackup(at: url, password: password, into: modelContext)
            password = ""
            confirmation = ""
            message = "已新增 \(count) 件事件。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
