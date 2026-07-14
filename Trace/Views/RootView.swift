import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @StateObject private var appLock = AppLockManager()

    var body: some View {
        Group {
            if appLock.isUnlocked {
                TabView {
                    EventListView()
                        .tabItem { Label("事件", systemImage: "tray.full") }
                    CaptureView()
                        .tabItem { Label("快速加入", systemImage: "plus.circle.fill") }
                    PrivacyView()
                        .tabItem { Label("資料與隱私", systemImage: "lock.shield") }
                }
                .tint(TraceTheme.moss)
            } else {
                LockScreen()
            }
        }
        .environmentObject(appLock)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { appLock.lockForBackground() }
        }
        .task {
            _ = try? SharedImportIngestor.ingestPendingBatches(into: modelContext)
        }
    }
}

private struct LockScreen: View {
    @EnvironmentObject private var appLock: AppLockManager

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(TraceTheme.moss)
            Text("留痕已鎖定")
                .font(.title2.bold())
            Text("使用 Face ID、Touch ID 或裝置密碼解鎖。")
                .foregroundStyle(.secondary)
            Button("解鎖") { Task { await appLock.authenticate() } }
                .buttonStyle(.borderedProminent)
            if let failureMessage = appLock.failureMessage {
                Text(failureMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(TraceTheme.paper)
        .task { await appLock.authenticate() }
    }
}
