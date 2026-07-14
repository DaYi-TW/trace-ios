import Foundation
import LocalAuthentication

@MainActor
final class AppLockManager: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.preferenceKey)
            if !isEnabled { isUnlocked = true }
        }
    }
    @Published private(set) var isUnlocked: Bool
    @Published private(set) var failureMessage: String?

    private static let preferenceKey = "trace.appLockEnabled"

    init() {
        let enabled = UserDefaults.standard.bool(forKey: Self.preferenceKey)
        isEnabled = enabled
        isUnlocked = !enabled
    }

    func lockForBackground() {
        if isEnabled { isUnlocked = false }
    }

    func authenticate() async {
        failureMessage = nil
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            failureMessage = "這台裝置無法使用裝置密碼或生物辨識解鎖。"
            return
        }

        do {
            try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "解鎖你的工作事件與附件"
            )
            isUnlocked = true
        } catch {
            failureMessage = "未完成解鎖。你可以再試一次。"
        }
    }
}
