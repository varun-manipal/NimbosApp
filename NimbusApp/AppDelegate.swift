import UIKit
import UserNotifications

extension Notification.Name {
    static let nimbusTaskAdded    = Notification.Name("nimbusTaskAdded")
    static let nimbusDailySummary = Notification.Name("nimbusDailySummary")
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - APNs Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        let timezone = TimeZone.current.identifier
        #if DEBUG
        let sandbox = true
        #else
        let sandbox = false
        #endif
        print("[APNs] Token registered (sandbox=\(sandbox)): \(hex)")

        // Cache locally so we can re-send after login if auth wasn't ready yet.
        UserDefaults.standard.set(hex, forKey: "nimbus_pendingApnsToken")
        UserDefaults.standard.set(timezone, forKey: "nimbus_pendingApnsTimezone")
        UserDefaults.standard.set(sandbox, forKey: "nimbus_pendingApnsSandbox")

        guard APIClient.shared.isRegistered else {
            print("[APNs] Not logged in — token cached, will send after login")
            return
        }
        Task {
            do {
                try await APIClient.shared.updateApnsToken(hex, timezone: timezone, sandbox: sandbox)
                print("[APNs] Token sent to backend ✓")
            } catch {
                print("[APNs] Failed to send token to backend: \(error)")
            }
        }
    }

    // Call this immediately after saving the auth token on login.
    // If the APNs token arrived before the user was authenticated, this sends it now.
    static func flushCachedApnsToken(role: String = "solo") {
        guard let hex = UserDefaults.standard.string(forKey: "nimbus_pendingApnsToken"),
              let tz  = UserDefaults.standard.string(forKey: "nimbus_pendingApnsTimezone"),
              APIClient.shared.isRegistered else { return }
        let sandbox = UserDefaults.standard.bool(forKey: "nimbus_pendingApnsSandbox")
        print("[APNs] Flushing cached token after login (role=\(role))")
        Task {
            do {
                try await APIClient.shared.updateApnsToken(hex, timezone: tz, sandbox: sandbox)
                print("[APNs] Token sent to backend ✓")
            } catch {
                print("[APNs] Failed to send cached token: \(error)")
            }
            await APIClient.shared.testPush(role: role)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Failed to register: \(error.localizedDescription)")
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Show banner + play sound even when app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Route push taps by payload `type` field
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        switch userInfo["type"] as? String {
        case "task_added":
            NotificationCenter.default.post(name: .nimbusTaskAdded, object: nil)
        case "daily_summary":
            NotificationCenter.default.post(name: .nimbusDailySummary, object: nil)
        default:
            break
        }
        completionHandler()
    }
}
