import SwiftUI
import SwiftData

struct NewEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var occurredAt = Date()
    @State private var context = ""
    @State private var narrative = ""
    @State private var workImpact = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("基本資料") {
                    TextField("事件標題，例如：臨時要求重做報告", text: $title)
                    DatePicker("大約發生時間", selection: $occurredAt)
                    TextField("工作情境或地點（選填）", text: $context)
                }
                Section("剛剛發生了什麼？") {
                    TextEditor(text: $narrative)
                        .frame(minHeight: 140)
                    Text("先用自己的方式寫下來。原始陳述會保留，不會被 AI 摘要覆蓋。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("具體工作影響（選填）") {
                    TextEditor(text: $workImpact)
                        .frame(minHeight: 90)
                }
            }
            .navigationTitle("建立事件")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let event = TraceEvent(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            occurredAt: occurredAt,
            context: context,
            narrative: narrative,
            workImpact: workImpact
        )
        modelContext.insert(event)
        dismiss()
    }
}
