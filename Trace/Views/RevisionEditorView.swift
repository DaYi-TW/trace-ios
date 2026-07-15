import SwiftUI
import SwiftData

struct RevisionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let event: TraceEvent
    @State private var context: String
    @State private var narrative: String
    @State private var workImpact: String

    init(event: TraceEvent) {
        self.event = event
        let revision = event.currentRevision
        _context = State(initialValue: revision?.context ?? event.context)
        _narrative = State(initialValue: revision?.narrative ?? event.narrative)
        _workImpact = State(initialValue: revision?.workImpact ?? event.workImpact)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("新增修正版") {
                    Text("原始陳述會保留不變；這次修改會建立新的版本。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("工作情境", text: $context)
                    TextEditor(text: $narrative)
                        .frame(minHeight: 150)
                    TextEditor(text: $workImpact)
                        .frame(minHeight: 90)
                }
            }
            .scrollContentBackground(.hidden)
            .background(TraceTheme.paper)
            .navigationTitle("新增修正版")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(narrative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let nextVersion = (event.revisions.map(\.versionNumber).max() ?? 0) + 1
        let revision = EventRevision(
            event: event,
            versionNumber: nextVersion,
            source: .userEdit,
            context: context,
            narrative: narrative,
            workImpact: workImpact
        )
        event.revisions.append(revision)
        event.currentRevisionID = revision.id
        event.touch()
        modelContext.insert(revision)
        dismiss()
    }
}
