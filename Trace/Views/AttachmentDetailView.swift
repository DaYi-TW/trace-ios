import SwiftData
import SwiftUI

struct AttachmentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var attachment: EvidenceAttachment
    @Query(sort: \ConversationMessage.orderIndex) private var allMessages: [ConversationMessage]
    @State private var isRecognizing = false
    @State private var isVerifying = false
    @State private var isTranscribing = false
    @State private var errorMessage: String?

    private var messages: [ConversationMessage] {
        allMessages.filter { $0.attachmentID == attachment.id }
    }

    var body: some View {
        Form {
            evidenceSection

            if attachment.kind == .image {
                chatSection
                ocrSection
                if !messages.isEmpty {
                    messageSection
                }
            } else if attachment.kind == .audio {
                audioSection
            }
        }
        .navigationTitle("附件詳情")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isRecognizing || isTranscribing {
                ProgressView("正在辨識文字…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert("無法完成操作", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var evidenceSection: some View {
        Section("原始附件") {
            LabeledContent("檔案名稱", value: attachment.fileName)
            LabeledContent("檔案大小", value: ByteCountFormatter.string(fromByteCount: attachment.byteCount, countStyle: .file))
            LabeledContent("匯入時間", value: attachment.importedAt.formatted(date: .long, time: .shortened))
            LabeledContent("SHA-256", value: attachment.sha256)
                .font(.caption)

            HStack {
                Label("完整性", systemImage: integrityIcon)
                Spacer()
                Text(integrityLabel)
                    .foregroundStyle(integrityColor)
            }

            Button {
                verifyIntegrity()
            } label: {
                Label(isVerifying ? "驗證中…" : "重新驗證原始檔", systemImage: "checkmark.shield")
            }
            .disabled(isVerifying)
        }
    }

    private var chatSection: some View {
        Section("聊天截圖整理") {
            Picker("來源 App", selection: $attachment.sourceApp) {
                Text("尚未確認").tag("")
                Text("LINE").tag("LINE")
                Text("Teams").tag("Teams")
                Text("Slack").tag("Slack")
                Text("Messenger").tag("Messenger")
                Text("Email").tag("Email")
                Text("其他").tag("其他")
            }
            Picker("聊天類型", selection: $attachment.conversationType) {
                Text("尚未確認").tag("")
                Text("一對一").tag("oneToOne")
                Text("群組").tag("group")
                Text("不確定").tag("unknown")
            }
            Picker("哪一側是你", selection: $attachment.sideMapping) {
                Text("尚未確認").tag("")
                Text("左側").tag("left")
                Text("右側").tag("right")
                Text("無法確認").tag("unknown")
            }
            Picker("截圖狀態", selection: $attachment.imageState) {
                Text("完整截圖").tag("完整截圖")
                Text("曾經裁切").tag("曾經裁切")
                Text("曾經標註或遮罩").tag("曾經標註")
                Text("不確定").tag("不確定")
            }
            TextField("畫面顯示的訊息時間（例如 14:32）", text: $attachment.displayedMessageTime)
            TextField("使用者確認的對話日期", text: $attachment.userConfirmedDate)
            Picker("日期可信度", selection: $attachment.dateAccuracy) {
                Text("確定").tag("確定")
                Text("推估").tag("推估")
                Text("未知").tag("未知")
            }
            Text("這些欄位只描述畫面與使用者確認內容，不會替你推定訊息真實發送時間或法律結論。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var ocrSection: some View {
        Section("本機 OCR") {
            if attachment.rawOCRText.isEmpty {
                Button {
                    recognize()
                } label: {
                    Label("在本機辨識聊天文字", systemImage: "text.viewfinder")
                }
                .disabled(isRecognizing)
            } else {
                LabeledContent("辨識狀態", value: attachment.ocrStatus)
                Text("系統辨識文字（可編輯）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $attachment.rawOCRText)
                    .frame(minHeight: 120)
                Text("確認後文字稿")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $attachment.confirmedText)
                    .frame(minHeight: 120)
                Button("確認這份文字稿") {
                    attachment.confirmedText = attachment.rawOCRText
                    attachment.ocrStatus = "已由使用者確認"
                    saveChanges()
                }
            }
            Text("OCR 僅是整理草稿；送出前請逐句核對原始圖片。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var audioSection: some View {
        Section("語音逐字稿") {
            if #available(iOS 26.0, *) {
                Button {
                    transcribeAudio()
                } label: {
                    Label(isTranscribing ? "轉錄中…" : "使用 Apple SpeechAnalyzer 轉錄", systemImage: "waveform")
                }
                .disabled(isTranscribing)
            } else {
                Text("Apple SpeechAnalyzer 需要 iOS 26 或以上；原始音檔仍可保存與匯出。")
                    .foregroundStyle(.secondary)
            }

            if !attachment.rawOCRText.isEmpty {
                Text("系統逐字稿（請核對音檔）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $attachment.rawOCRText)
                    .frame(minHeight: 160)
                Text("確認後逐字稿")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $attachment.confirmedText)
                    .frame(minHeight: 160)
                Button("確認這份逐字稿") {
                    attachment.confirmedText = attachment.rawOCRText
                    attachment.ocrStatus = "已由使用者確認"
                    saveChanges()
                }
            }
        }
    }

    private var messageSection: some View {
        Section("訊息排列草稿") {
            ForEach(messages) { message in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("第 \(message.orderIndex + 1) 則")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(message.side.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    TextField("訊息文字", text: Binding(
                        get: { message.text },
                        set: {
                            message.text = $0
                            message.isConfirmed = false
                        }
                    ), axis: .vertical)
                    Picker("訊息類型", selection: Binding(
                        get: { message.kind },
                        set: { message.kind = $0 }
                    )) {
                        Text("一般訊息").tag(ConversationMessageKind.message)
                        Text("引用內容").tag(ConversationMessageKind.quoted)
                        Text("系統訊息").tag(ConversationMessageKind.system)
                        Text("圖片或附件").tag(ConversationMessageKind.attachment)
                        Text("無法辨識").tag(ConversationMessageKind.unknown)
                    }
                    Toggle("我已核對這一則", isOn: Binding(
                        get: { message.isConfirmed },
                        set: { message.isConfirmed = $0 }
                    ))
                }
                .padding(.vertical, 4)
            }
            Button("確認全部訊息") {
                messages.forEach { $0.isConfirmed = true }
                saveChanges()
            }
        }
    }

    private var integrityLabel: String {
        switch attachment.integrityStatus {
        case .valid: return "已驗證"
        case .mismatch: return "雜湊不一致"
        case .missing: return "原始檔遺失"
        case .unverified: return "尚未驗證"
        }
    }

    private var integrityIcon: String {
        attachment.integrityStatus == .valid ? "checkmark.seal.fill" : "exclamationmark.triangle"
    }

    private var integrityColor: Color {
        attachment.integrityStatus == .valid ? .green : .orange
    }

    private func recognize() {
        isRecognizing = true
        Task {
            defer { isRecognizing = false }
            do {
                let url = try EvidenceStore.url(for: attachment)
                let draft = try await OCRService.recognize(in: Data(contentsOf: url))
                attachment.rawOCRText = draft.rawText
                attachment.ocrStatus = "已完成本機辨識，待使用者確認"

                allMessages
                    .filter { $0.attachmentID == attachment.id }
                    .forEach { modelContext.delete($0) }

                let result = OCRResult(
                    attachmentID: attachment.id,
                    engine: draft.engine,
                    localeIdentifiers: draft.localeIdentifiers,
                    rawText: draft.rawText,
                    observationsData: draft.observationsData
                )
                modelContext.insert(result)
                attachment.latestOCRResultID = result.id

                for (index, observation) in draft.observations.enumerated() {
                    let side: ConversationSide = observation.midpointX < 0.5 ? .left : .right
                    modelContext.insert(ConversationMessage(
                        attachmentID: attachment.id,
                        orderIndex: index,
                        side: side,
                        text: observation.text,
                        confidence: observation.confidence
                    ))
                }
                saveChanges()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func verifyIntegrity() {
        isVerifying = true
        defer { isVerifying = false }
        do {
            _ = try EvidenceStore.verify(attachment)
            saveChanges()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func transcribeAudio() {
        guard #available(iOS 26.0, *) else { return }
        isTranscribing = true
        Task {
            defer { isTranscribing = false }
            do {
                let url = try EvidenceStore.url(for: attachment)
                let transcript = try await SpeechAnalyzerService.transcribe(fileAt: url)
                attachment.rawOCRText = transcript
                attachment.ocrStatus = "已完成 Apple SpeechAnalyzer 轉錄，待使用者確認"
                saveChanges()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
