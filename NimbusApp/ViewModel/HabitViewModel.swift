import SwiftUI
import Combine
import CoreHaptics

class HabitViewModel: ObservableObject {
    @Published var tasks: [HabitTask] = []
    @Published var tomorrowExtras: [HabitTask] = []   // one-time tasks queued for tomorrow only
    @Published var totalStarsLit: Int = 0    // lifetime cumulative — drives Nimbos evolution, never decrements
    @Published var dailyStarsLit: Int = 0    // today only — resets at dawn, can decrement on un-toggle
    @Published var userName: String = ""
    @Published var selectedVibe: VibeType = .bestie
    @Published var listPin: String = ""
    @Published var lastCompletedId: UUID? = nil
    @Published var showMorningMist: Bool = false
    @Published var showMilestoneVideo: Bool = false
    @Published var shield: Shield = Shield()

    private var hapticEngine: CHHapticEngine?

    // MARK: - Persistence Keys

    private enum Keys {
        static let tasks          = "nimbus_tasks"
        static let tomorrowExtras = "nimbus_tomorrowExtras"
        static let totalStarsLit  = "nimbus_totalStarsLit"
        static let dailyStarsLit  = "nimbus_dailyStarsLit"
        static let userName       = "nimbus_userName"
        static let selectedVibe   = "nimbus_selectedVibe"
        static let shield         = "nimbus_shield"
        static let listPin        = "nimbus_pin"
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

    func addTask(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        tasks.append(HabitTask(title: trimmed))
        save()
    }

    func removeTask(_ task: HabitTask) {
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func renameTask(_ task: HabitTask, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].title = trimmed
        save()
    }

    // MARK: - Tomorrow Planner

    func toggleSkipTomorrow(_ task: HabitTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isSkippedTomorrow.toggle()
        save()
    }

    func addTomorrowExtra(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        tomorrowExtras.append(HabitTask(title: trimmed))
        save()
    }

    func removeTomorrowExtra(_ task: HabitTask) {
        tomorrowExtras.removeAll { $0.id == task.id }
        save()
    }

    var hasTomorrowPlan: Bool {
        tasks.contains { $0.isSkippedTomorrow } || !tomorrowExtras.isEmpty
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
        d.set(listPin, forKey: Keys.listPin)
        if let encoded = try? JSONEncoder().encode(tasks) {
            d.set(encoded, forKey: Keys.tasks)
        }
        if let encoded = try? JSONEncoder().encode(tomorrowExtras) {
            d.set(encoded, forKey: Keys.tomorrowExtras)
        }
        if let encoded = try? JSONEncoder().encode(shield) {
            d.set(encoded, forKey: Keys.shield)
        }
    }

    /// Re-reads all persisted data. Call after onboarding completes.
    func reload() { load() }

    private func load() {
        let d = UserDefaults.standard
        totalStarsLit = d.integer(forKey: Keys.totalStarsLit)
        dailyStarsLit = d.integer(forKey: Keys.dailyStarsLit)
        userName      = d.string(forKey: Keys.userName) ?? ""
        listPin       = d.string(forKey: Keys.listPin) ?? ""
        if let raw  = d.string(forKey: Keys.selectedVibe),
           let vibe = VibeType(rawValue: raw) {
            selectedVibe = vibe
        }
        if let data    = d.data(forKey: Keys.tasks),
           let decoded = try? JSONDecoder().decode([HabitTask].self, from: data) {
            tasks = decoded
        }
        if let data    = d.data(forKey: Keys.tomorrowExtras),
           let decoded = try? JSONDecoder().decode([HabitTask].self, from: data) {
            tomorrowExtras = decoded
        }
        if let data    = d.data(forKey: Keys.shield),
           let decoded = try? JSONDecoder().decode(Shield.self, from: data) {
            shield = decoded
        }
    }
}
