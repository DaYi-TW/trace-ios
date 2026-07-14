import SwiftUI

struct AttachmentDetailView: View {
    @Bindable var attachment: EvidenceAttachment
    @State private var isRecognizing = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("原始資料") {
                LabeledContent("檔案", value: attachment.fileName)
                LabeledContent("匯入時間", value: attachment.importedAt.formatted(date: .long, time: .shortened))
                LabeledContent("SHA-256", value: attachment.sha256)
                Text("SHA-256 只能驗證儲存後檔案是否改變，不能證明截圖真偽或訊息實際發送時間。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if attachment.kind == .image {
                Section("聊天截圖資訊") {
                    Picker("圖片狀態", selection: $attachment.imageState) {
                        Text("完整截圖").tag("完整截圖")
                        Text("曾經裁切").tag("曾經裁切")
                        Text("曾經標註或遮罩").tag("曾經標註或遮罩")
                        Text("不確定").tag("不確定")
                    }
                    TextField("畫面顯示的訊息時間（選填）", text: $attachment.displayedMessageTime)
                    TextField("使用者確認的對話日期（選填）", text: $attachment.userConfirmedDate)
                    Picker("日期準確度", selection: $attachment.dateAccuracy) {
                        Text("確定").tag("確定")
                        Text("推估").tag("推估")
                        Text("未知").tag("未知")
                    }
                }
                Section("OCR") {
                    if attachment.rawOCRText.isEmpty {
                        Button { recognize() } label: {
                            Label("在本機辨識圖片文字", systemImage: "text.viewfinder")
                        }
                        .disabled(isRecognizing)
                    } else {
                        Text("系統辨識文字，請使用者確認。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $attachment.rawOCRText)
                            .frame(minHeight: 120)
                        TextEditor(text: $attachment.confirmedText)
                            .frame(minHeight: 120)
                        Button("標記為已確認") {
                            attachment.ocrStatus = "已由使用者確認"
                            if attachment.confirmedText.isEmpty { attachment.confirmedText = attachment.rawOCRText }
                        }
                    }
                }
            }
        }
        .navigationTitle("附件詳情")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if isRecognizing { ProgressView("正在本機辨識文字…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
        .alert("OCR 失敗", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func recognize() {
        isRecognizing = true
        Task {
            defer { isRecognizing = false }
            do {
                let url = try EvidenceStore.url(for: attachment)
                attachment.rawOCRText = try await OCRService.recognizeText(in: Data(contentsOf: url))
                attachment.ocrStatus = "待使用者確認"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
