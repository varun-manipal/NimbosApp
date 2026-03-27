import SwiftUI
import Observation
import CoreHaptics

@Observable
class HabitViewModel {
    var tasks: [HabitTask] = []
    var totalStarsLit: Int = 0    // lifetime cumulative — drives Nimbos evolution, never decrements
    var dailyStarsLit: Int = 0    // today only — resets at dawn, can decrement on un-toggle
    var userName: String = ""
    var selectedVibe: VibeType = .bestie
    var lastCompletedId: UUID? = nil
    var showMorningMist: Bool = false
    var showMilestoneVideo: Bool = false
    var shield: Shield = Shield()

    private var hapticEngine: CHHapticEngine?

    // MARK: - Persistence Keys

    private enum Keys {
        static let tasks          = "nimbus_tasks"
        static let totalStarsLit  = "nimbus_totalStarsLit"
        static let dailyStarsLit  = "nimbus_dailyStarsLit"
        static let userName       = "nimbus_userName"
        static let selectedVibe   = "nimbus_selectedVibe"
        static let shield         = "nimbus_shield"
    }

    init() {
        load()
        prepareHaptics()
    }

    // MARK: - Computed Properties

    var nimbosStateImage: String {
        if totalStarsLit < 12 { return "Nimbos Stage 1" }
        if totalStarsLit < 35 { return "Nimbos Stage 2" }
        if totalStarsLit < 50 { return "Nimbos Stage 3" }
        return "Nimbos Stage 4"
    }

    var totalProgress: Double {
        if totalStarsLit < 12 { return Double(totalStarsLit) / 12.0 }
        if totalStarsLit < 35 { return Double(totalStarsLit - 12) / 23.0 }
        if totalStarsLit < 50 { return Double(totalStarsLit - 35) / 15.0 }
        return 1.0
    }

    var dailyCompletionPercentage: Double {
        let active = tasks.filter { !$0.isSnoozed && !$0.isDismissedToday }
        guard !active.isEmpty else { return 0 }
        let completed = active.filter { $0.isCompleted }.count
        return Double(completed) / Double(active.count)
    }

    /// Shown when a shield fragment was consumed to protect yesterday's streak.
    var shieldDialogue: String? {
        guard shield.isActive else { return nil }
        let name = userName.isEmpty ? "Guardian" : userName
        return "I used a fragment to protect us last night, \(name). Let's make it count today. 🛡️"
    }

    /// Vibe-personalised dialogue shown when daily completion is below 20%.
    var nimbosDialogue: String? {
        let active = tasks.filter { !$0.isSnoozed && !$0.isDismissedToday }
        guard !active.isEmpty, dailyCompletionPercentage < 0.2 else { return nil }
        let name = userName.isEmpty ? "Guardian" : userName
        return selectedVibe == .bestie
            ? "The fog is heavy today, \(name). I'm just glad you opened the app to sit with me."
            : "The fog is creeping in. Check a box and let's clear it out. Now. 🔥"
    }

    // MARK: - Task Actions

    func toggleTask(_ task: HabitTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }),
              !tasks[index].isDismissedToday else { return }
        tasks[index].isCompleted.toggle()

        if tasks[index].isCompleted {
            totalStarsLit += 1
            dailyStarsLit += 1
            lastCompletedId = task.id
            if totalStarsLit == 12 { showMilestoneVideo = true }
            triggerCompletionHaptic()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { self.lastCompletedId = nil }
            }
        } else {
            totalStarsLit = max(0, totalStarsLit - 1)
            dailyStarsLit = max(0, dailyStarsLit - 1)
        }
        save()
    }

    func snoozeTask(_ task: HabitTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isSnoozed = true
        save()
    }

    func dismissTask(_ task: HabitTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isDismissedToday = true
        save()
    }

    // MARK: - Haptics

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        hapticEngine = try? CHHapticEngine()
        hapticEngine?.stoppedHandler = { [weak self] _ in self?.hapticEngine = nil }
        try? hapticEngine?.start()
    }

    private func triggerCompletionHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        do {
            // Sharp transient "pop"
            let pop = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0
            )
            // Short low rumble that follows
            let rumble = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.35),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                ],
                relativeTime: 0.05,
                duration: 0.12
            )
            let pattern = try CHHapticPattern(events: [pop, rumble], parameters: [])
            try engine.makePlayer(with: pattern).start(atTime: 0)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Persistence

    func save() {
        let d = UserDefaults.standard
        d.set(totalStarsLit, forKey: Keys.totalStarsLit)
        d.set(dailyStarsLit, forKey: Keys.dailyStarsLit)
        d.set(userName, forKey: Keys.userName)
        d.set(selectedVibe.rawValue, forKey: Keys.selectedVibe)
        if let encoded = try? JSONEncoder().encode(tasks) {
            d.set(encoded, forKey: Keys.tasks)
        }
        if let encoded = try? JSONEncoder().encode(shield) {
            d.set(encoded, forKey: Keys.shield)
        }
    }

    private func load() {
        let d = UserDefaults.standard
        totalStarsLit = d.integer(forKey: Keys.totalStarsLit)
        dailyStarsLit = d.integer(forKey: Keys.dailyStarsLit)
        userName      = d.string(forKey: Keys.userName) ?? ""
        if let raw  = d.string(forKey: Keys.selectedVibe),
           let vibe = VibeType(rawValue: raw) {
            selectedVibe = vibe
        }
        if let data    = d.data(forKey: Keys.tasks),
           let decoded = try? JSONDecoder().decode([HabitTask].self, from: data) {
            tasks = decoded
        }
        if let data    = d.data(forKey: Keys.shield),
           let decoded = try? JSONDecoder().decode(Shield.self, from: data) {
            shield = decoded
        }
    }
}
