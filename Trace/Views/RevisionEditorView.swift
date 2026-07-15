import SwiftData
import SwiftUI

struct RevisionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let event: TraceEvent
    @State private var context: String
    @State private var narrative: String
    @State private var workImpact: String
    @State private var uncertainties: [String]
    @State private var revisionSource: EventRevisionSource = .userEdit
    @State private var isGenerating = false
    @State private var errorMessage: String?

    init(event: TraceEvent) {
        self.event = event
        let revision = event.currentRevision
        _context = State(initialValue: revision?.context ?? event.context)
        _narrative = State(initialValue: revision?.narrative ?? event.narrative)
        _workImpact = State(initialValue: revision?.workImpact ?? event.workImpact)
        _uncertainties = State(initialValue: revision?.uncertainties ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("事件修訂版") {
                    Text("原始紀錄不會被覆寫。儲存後會建立新的使用者修訂版，並保留版本與來源。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("工作情境", text: $context)
                    TextEditor(text: $narrative)
                        .frame(minHeight: 150)
                    TextEditor(text: $workImpact)
                        .frame(minHeight: 90)
                }

                Section("Apple Intelligence（可選）") {
                    if #available(iOS 26.0, *) {
                        Button {
                            generateDraft()
                        } label: {
                            Label(isGenerating ? "正在產生中…" : "產生中性整理草稿", systemImage: "sparkles")
                        }
                        .disabled(isGenerating)
                        Text("AI 只會整理你提供的附件與文字，不會判定是否構成霸凌或違法；結果一定要由你核對後再保存。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Apple Intelligence 需要 iOS 26 或以上。你仍可手動建立修訂版。")
                            .foregroundStyle(.secondary)
                    }
                    if !uncertainties.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("待確認事項")
                                .font(.caption.weight(.semibold))
                            ForEach(uncertainties, id: \.self) { Text("• \($0)") }
                                .font(.footnote)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(TraceTheme.paper)
            .navigationTitle("編輯事件修訂版")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存修訂") { save() }
                        .disabled(narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .overlay {
                if isGenerating {
                    ProgressView("正在整理附件…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert("無法產生 AI 草稿", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func generateDraft() {
        guard #available(iOS 26.0, *) else { return }
        isGenerating = true
        Task {
            defer { isGenerating = false }
            do {
                let draft = try await AppleIntelligenceService.draft(for: event)
                context = draft.context
                narrative = draft.narrative
                workImpact = draft.workImpact
                uncertainties = draft.uncertainties
                revisionSource = .confirmedAI
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func save() {
        let nextVersion = (event.revisions.map(\.versionNumber).max() ?? 0) + 1
        let revision = EventRevision(
            event: event,
            versionNumber: nextVersion,
            source: revisionSource,
            context: context,
            narrative: narrative,
            workImpact: workImpact,
            uncertainties: uncertainties
        )
        event.revisions.append(revision)
        event.currentRevisionID = revision.id
        event.touch()
        modelContext.insert(revision)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
