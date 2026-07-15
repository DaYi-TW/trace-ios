import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @StateObject private var appLock = AppLockManager()
    @State private var isPrivacyShielded = false

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
        .overlay {
            if isPrivacyShielded {
                PrivacyShieldView()
                    .accessibilityHidden(true)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive:
                // Cover the UI before iOS captures the app-switcher snapshot.
                isPrivacyShielded = true
            case .background:
                appLock.lockForBackground()
                isPrivacyShielded = true
            case .active:
                isPrivacyShielded = appLock.isEnabled && !appLock.isUnlocked
            @unknown default:
                isPrivacyShielded = true
            }
        }
        .onChange(of: appLock.isUnlocked) { _, isUnlocked in
            if isUnlocked && scenePhase == .active {
                isPrivacyShielded = false
            }
        }
        .task {
            _ = try? DataMigrationService.backfillOriginalRevisions(in: modelContext)
            _ = try? SharedImportIngestor.ingestPendingBatches(into: modelContext)
        }
    }
}

private struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .transition(.opacity)
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
