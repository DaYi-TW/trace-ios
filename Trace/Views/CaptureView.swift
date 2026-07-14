import SwiftUI

struct CaptureView: View {
    @State private var showingNewEvent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Text("加入材料")
                    .font(TraceTheme.titleFont(34))
                    .foregroundStyle(TraceTheme.ink)
                Text("從相簿、Files 或 iOS 分享選單保存你主動選擇的材料。先保存，整理可以稍後再做。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TraceTheme.muted)
                    .padding(.horizontal, 28)
                Button("建立事件並加入截圖") { showingNewEvent = true }
                    .buttonStyle(TracePrimaryButtonStyle())
                    .padding(.horizontal, 24)
                Text("安裝測試版後，可在相簿分享選單選擇「加入留痕」，再回到 App 補齊事件資訊。")
                    .font(.footnote)
                    .foregroundStyle(TraceTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Spacer()
            }
            .background(TraceTheme.paper)
            .navigationTitle("加入")
            .sheet(isPresented: $showingNewEvent) { NewEventView() }
        }
    }
}
