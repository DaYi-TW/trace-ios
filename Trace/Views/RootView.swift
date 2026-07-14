import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            EventListView()
                .tabItem { Label("事件", systemImage: "tray.full") }
            CaptureView()
                .tabItem { Label("快速加入", systemImage: "plus.circle.fill") }
            PrivacyView()
                .tabItem { Label("資料與隱私", systemImage: "lock.shield") }
        }
        .tint(.indigo)
    }
}
