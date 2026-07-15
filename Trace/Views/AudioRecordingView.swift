import SwiftData
import SwiftUI

struct AudioRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var recorder: AudioRecorderService
    let event: TraceEvent
    @State private var errorMessage: String?
    @State private var hasPermission = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: recorder.isRecording ? "waveform.circle.fill" : "waveform.circle")
                    .font(.system(size: 72))
                    .foregroundStyle(recorder.isRecording ? .red : TraceTheme.moss)
                    .symbolEffect(.pulse, isActive: recorder.isRecording)

                Text(recorder.isRecording ? "正在錄音（畫面可見）" : "開始可見錄音")
                    .font(.title2.bold())
                Text(formattedDuration)
                    .font(.system(size: 42, weight: .medium, design: .monospaced))
                    .foregroundStyle(TraceTheme.ink)

                Text("錄音只會在你按下開始後進行；iOS 會顯示麥克風使用狀態。停止後，檔案會加入目前事件。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if recorder.permissionDenied {
                    Label("尚未取得麥克風權限，請到設定開啟。", systemImage: "mic.slash")
                        .foregroundStyle(.red)
                }

                if recorder.isRecording {
                    HStack(spacing: 16) {
                        Button("取消") {
                            recorder.cancel()
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        Button("停止並保存", systemImage: "stop.fill") {
                            finishRecording()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                } else {
                    Button("開始錄音", systemImage: "record.circle.fill") {
                        startRecording()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!hasPermission)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("語音紀錄")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                hasPermission = await recorder.requestPermission()
            }
            .alert("無法完成錄音", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var formattedDuration: String {
        let seconds = Int(recorder.elapsed)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func startRecording() {
        do {
            try recorder.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishRecording() {
        guard let url = recorder.stop() else {
            errorMessage = "錄音檔尚未產生，請重試。"
            return
        }
        do {
            let attachment = try EvidenceStore.store(fileAt: url)
            attachment.sourceDescription = "使用者在 Trace 內可見錄音"
            attachment.event = event
            modelContext.insert(attachment)
            try modelContext.save()
            try? FileManager.default.removeItem(at: url)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
