import Foundation
import Combine
import UIKit
import UserNotifications

class NotificationViewModel: ObservableObject {

    // MARK: - Permission

    func requestPermission(then schedule: (() -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
                schedule?()
            }
        }
    }

    // MARK: - Schedule All Standing Notifications

    /// Call after onboarding and on each foreground open.
    /// Checks authorization before scheduling — silently skips if permission is denied.
    func scheduleAll(userName: String, vibe: VibeType, role: String) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let authorized = settings.authorizationStatus == .authorized
                          || settings.authorizationStatus == .provisional
            guard authorized else {
                print("[Notifications] Skipping schedule — status: \(settings.authorizationStatus.rawValue)")
                return
            }
            DispatchQueue.main.async {
                self?.scheduleMorning(userName: userName, vibe: vibe, role: role)
                self?.scheduleGhosting(userName: userName, vibe: vibe)
                if role == UserRole.child.rawValue {
                    self?.scheduleAfternoon(userName: userName, vibe: vibe)
                } else {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nimbus_afternoon"])
                }
                if role == UserRole.solo.rawValue {
                    self?.scheduleEvening(userName: userName, vibe: vibe)
                }
            }
        }
    }

    // MARK: - Morning (8 am daily)

    private func scheduleMorning(userName: String, vibe: VibeType, role: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nimbus_morning"])

        let content = UNMutableNotificationContent()
        content.sound = .default

        let name = userName.isEmpty ? "" : ", \(userName)"
        let isChild = role == UserRole.child.rawValue

        if vibe == .bestie {
            content.title = "Good morning\(name)! ☁️"
            content.body  = isChild
                ? "Your tasks are waiting. Let's light some stars today! ✨"
                : "Let's make the sky sparkle today. ✨"
        } else {
            content.title = isChild ? "Morning, \(userName.isEmpty ? "you" : userName)." : "Day streak\(name)."
            content.body  = isChild ? "Task list. Open it. Now." : "The sky is waiting. Let's get to work."
        }

        var comps = DateComponents()
        comps.hour   = 8
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "nimbus_morning", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] Morning schedule failed: \(error)")
            } else {
                print("[Notifications] Morning (8AM) scheduled for role=\(role)")
            }
        }
    }

    // MARK: - Afternoon (3 pm daily — child only)

    private func scheduleAfternoon(userName: String, vibe: VibeType) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nimbus_afternoon"])

        let content = UNMutableNotificationContent()
        content.sound = .default

        let name = userName.isEmpty ? "" : ", \(userName)"
        if vibe == .bestie {
            content.title = "Hey\(name) ☁️"
            content.body  = "Afternoon check-in! How are your tasks going?"
        } else {
            content.title = "3PM\(name)."
            content.body  = "Half the day's gone. Have you checked your tasks?"
        }

        var comps = DateComponents()
        comps.hour   = 15
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "nimbus_afternoon", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Evening (9 pm — solo users only; cancel if day is already ≥ 50% done)

    func scheduleEvening(userName: String, vibe: VibeType) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nimbus_evening"])

        let content = UNMutableNotificationContent()
        content.sound = .default

        let name = userName.isEmpty ? "" : ", \(userName)"
        if vibe == .bestie {
            content.title = "Hey\(name) ☁️"
            content.body  = "It's okay! We'll catch that star tomorrow. You're doing great."
        } else {
            content.title = "The fog is creeping in\(name)."
            content.body  = "Check a box and let's clear it out. Now. 🔥"
        }

        var comps = DateComponents()
        comps.hour   = 21
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "nimbus_evening", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelEvening() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nimbus_evening"])
    }

    // MARK: - Debug Test (fires morning notification after a short delay)

    func scheduleTestMorning(userName: String, vibe: VibeType, role: String, delay: TimeInterval = 5) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nimbus_morning_test"])

        let content = UNMutableNotificationContent()
        content.sound = .default
        let name = userName.isEmpty ? "" : ", \(userName)"
        content.title = "Good morning\(name)! ☁️ (test)"
        content.body  = role == UserRole.child.rawValue
            ? "Your tasks are waiting. Let's light some stars today! ✨"
            : "Let's make the sky sparkle today. ✨"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: "nimbus_morning_test", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notifications] Test schedule failed: \(error)")
            } else {
                print("[Notifications] Test morning notification fires in \(delay)s")
            }
        }
    }

    // MARK: - Ghosting Recovery (3-day no-open)

    private func scheduleGhosting(userName: String, vibe: VibeType) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nimbus_ghosting"])

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = "Nimbos found something ☁️"
        content.body  = "A Star Shard appeared while you were away. Want to see what color it is?"

        let fireDate = Date().addingTimeInterval(3 * 24 * 60 * 60)
        let trigger  = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
        let request  = UNNotificationRequest(identifier: "nimbus_ghosting", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
