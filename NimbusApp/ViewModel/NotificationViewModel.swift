import Foundation
import Combine
import UserNotifications

class NotificationViewModel: ObservableObject {

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Schedule All Standing Notifications

    /// Call after onboarding and on each foreground open.
    /// Morning and ghosting notifications are rescheduled; evening is handled separately.
    func scheduleAll(userName: String, vibe: VibeType) {
        scheduleMorning(userName: userName, vibe: vibe)
        scheduleGhosting(userName: userName, vibe: vibe)
    }

    // MARK: - Morning (8 am daily)

    private func scheduleMorning(userName: String, vibe: VibeType) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nimbus_morning"])

        let content = UNMutableNotificationContent()
        content.sound = .default

        let name = userName.isEmpty ? "" : ", \(userName)"
        if vibe == .bestie {
            content.title = "Good morning\(name)! ☁️"
            content.body  = "Let's make the sky sparkle today. ✨"
        } else {
            content.title = "Day streak\(name)."
            content.body  = "The sky is waiting. Let's get to work."
        }

        var comps = DateComponents()
        comps.hour   = 8
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: "nimbus_morning", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Evening (9 pm — cancel if day is already ≥ 50% done)

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

    // MARK: - Ghosting Recovery (3-day no-open)

    /// Reset the ghosting timer every time the user opens the app.
    private func scheduleGhosting(userName: String, vibe: VibeType) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nimbus_ghosting"])

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = "Nimbos found something ☁️"
        content.body  = "A Star Shard appeared while you were away. Want to see what color it is?"

        // Fire once, 3 days from now
        let fireDate = Date().addingTimeInterval(3 * 24 * 60 * 60)
        let trigger  = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
        let request  = UNNotificationRequest(identifier: "nimbus_ghosting", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
