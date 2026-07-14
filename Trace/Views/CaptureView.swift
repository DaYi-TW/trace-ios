import SwiftUI

struct CaptureView: View {
    @State private var showingNewEvent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.indigo)
                Text("先保存，再慢慢整理")
                    .font(.title2.bold())
                Text("建立一件事件後，可匯入 LINE、Teams 或其他聊天截圖。留痕只處理你主動選擇分享的檔案。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 28)
                Button("建立事件並加入截圖") { showingNewEvent = true }
                    .buttonStyle(.borderedProminent)
                Text("安裝測試版後，可在相簿分享選單選擇「加入留痕」，再回到 App 補齊事件資訊。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .navigationTitle("快速加入")
            .sheet(isPresented: $showingNewEvent) { NewEventView() }
        }
    }
}
