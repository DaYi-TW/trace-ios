import PhotosUI
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct EventDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var event: TraceEvent
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showingFileImporter = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var exportURL: URL?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 9) {
                    Text("CASE PACKAGE · DRAFT")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(TraceTheme.muted)
                    Text(event.title)
                        .font(TraceTheme.titleFont(26))
                        .foregroundStyle(TraceTheme.ink)
                    Text("\(event.attachments.count) 份材料 · 事件資料可隨時修正")
                        .font(.system(size: 12))
                        .foregroundStyle(TraceTheme.muted)
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(TraceTheme.paper)
            Section("事件") {
                TextField("標題", text: $event.title)
                DatePicker("發生時間", selection: $event.occurredAt)
                TextField("工作情境", text: $event.context)
                NavigationLink("新增事件修正版") {
                    RevisionEditorView(event: event)
                }
            }
            Section("目前修訂版") {
                if let revision = event.currentRevision {
                    LabeledContent("工作情境") { Text(revision.context.isEmpty ? "未填寫" : revision.context) }
                    LabeledContent("事件陳述") { Text(revision.narrative.isEmpty ? "未填寫" : revision.narrative) }
                    LabeledContent("工作影響") { Text(revision.workImpact.isEmpty ? "未填寫" : revision.workImpact) }
                    Text("版本 (revision.versionNumber) · (revision.sourceRawValue)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("尚未建立修訂版").foregroundStyle(.secondary)
                }
            }
            Section("原始陳述") {
                Text(event.narrative.isEmpty ? "未填寫" : event.narrative)
                    .textSelection(.enabled)
                Text("原始陳述建立後不可覆寫；需要補充時請新增修正版。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("加入材料") {
                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 20, matching: .images) {
                    Label("從相簿加入聊天截圖", systemImage: "photo.on.rectangle")
                }
                Button { showingFileImporter = true } label: {
                    Label("從 Files 加入文件或音檔", systemImage: "folder")
                }
                Text("先保存原始檔；OCR 與對話整理可稍後完成。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("附件（\(event.attachments.count)）") {
                if event.attachments.isEmpty {
                    Text("尚未加入材料").foregroundStyle(.secondary)
                }
                ForEach(event.attachments) { attachment in
                    NavigationLink(value: attachment) {
                        AttachmentRow(attachment: attachment)
                    }
                }
                .onDelete(perform: deleteAttachments)
            }
            Section {
                Button { exportPDF() } label: {
                    Label("匯出事件摘要 PDF", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("PDF 是事件整理摘要；原始附件應以完整案件包另行選擇分享。")
            }
        }
        .scrollContentBackground(.hidden)
        .background(TraceTheme.paper)
        .tint(TraceTheme.moss)
        .navigationTitle("事件詳情")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: event.title) { _, _ in event.touch() }
        .onChange(of: event.narrative) { _, _ in event.touch() }
        .onChange(of: selectedPhotos) { _, items in
            Task { await importPhotos(items) }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.image, .pdf, .audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): importFiles(urls)
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .navigationDestination(for: EvidenceAttachment.self) { attachment in
            AttachmentDetailView(attachment: attachment)
        }
        .overlay { if isImporting { ProgressView("正在保存材料…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
        .alert("無法完成操作", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("好", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .sheet(isPresented: Binding(get: { exportURL != nil }, set: { if !$0 { exportURL = nil } })) {
            if let exportURL {
                ActivityView(items: [exportURL])
            }
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isImporting = true
        defer { selectedPhotos = []; isImporting = false }
        for (index, item) in items.enumerated() {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let fileName = "聊天截圖-\(index + 1).\(EvidenceStore.imageFileExtension(for: data))"
                let attachment = try EvidenceStore.store(data: data, preferredFileName: fileName, kind: .image)
                attachment.event = event
                modelContext.insert(attachment)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        event.touch()
    }

    private func importFiles(_ urls: [URL]) {
        isImporting = true
        defer { isImporting = false }
        for url in urls {
            do {
                let attachment = try EvidenceStore.store(fileAt: url)
                attachment.event = event
                modelContext.insert(attachment)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        event.touch()
    }

    private func deleteAttachments(at offsets: IndexSet) {
        let attachments = offsets.compactMap { index in
            event.attachments.indices.contains(index) ? event.attachments[index] : nil
        }
        do {
            for attachment in attachments {
                try EvidenceDeletionService.delete(attachment: attachment, from: modelContext)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        event.touch()
    }

    private func exportPDF() {
        do {
            exportURL = try PDFExporter.makePDF(for: event)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AttachmentRow: View {
    let attachment: EvidenceAttachment
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(attachment.fileName, systemImage: attachment.kind == .image ? "photo" : "doc")
            Text("\(attachment.ocrStatus) · \(attachment.importedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
