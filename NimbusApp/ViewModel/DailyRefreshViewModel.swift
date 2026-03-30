import Foundation
import Combine

struct DailySnapshot: Codable {
    let date: Date
    let completionPercentage: Double
    let starsLit: Int
}

class DailyRefreshViewModel: ObservableObject {

    private enum Keys {
        static let lastOpenedDate = "nimbus_lastOpenedDate"
        static let snapshots      = "nimbus_dailySnapshots"
    }

    /// Call this whenever the app enters the foreground.
    /// Resets tasks and archives yesterday's snapshot if a new calendar day has begun.
    func checkForNewDay(habitViewModel: HabitViewModel) {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())

        guard let lastOpened = UserDefaults.standard.object(forKey: Keys.lastOpenedDate) as? Date else {
            // First ever open — record today and leave tasks untouched.
            UserDefaults.standard.set(today, forKey: Keys.lastOpenedDate)
            return
        }

        if calendar.isDate(lastOpened, inSameDayAs: today) {
            // Same day — nothing to do.
            return
        }

        // New day: archive yesterday's progress, then reset.
        archiveSnapshot(for: habitViewModel)

        for i in habitViewModel.tasks.indices {
            habitViewModel.tasks[i].isCompleted      = false
            habitViewModel.tasks[i].isSnoozed        = false
            habitViewModel.tasks[i].isDismissedToday = false
        }
        habitViewModel.dailyStarsLit = 0
        habitViewModel.save()

        UserDefaults.standard.set(today, forKey: Keys.lastOpenedDate)

        // Signal the dashboard to show the Morning Mist animation.
        habitViewModel.showMorningMist = true
    }

    // MARK: - Snapshot Persistence

    private func archiveSnapshot(for habitViewModel: HabitViewModel) {
        let pct = habitViewModel.dailyCompletionPercentage
        let snapshot = DailySnapshot(
            date: UserDefaults.standard.object(forKey: Keys.lastOpenedDate) as? Date ?? Date(),
            completionPercentage: pct,
            starsLit: habitViewModel.dailyStarsLit
        )
        var all = loadSnapshots()
        all.append(snapshot)
        if let encoded = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(encoded, forKey: Keys.snapshots)
        }

        // Shield logic: award fragment on perfect day, consume on missed day
        habitViewModel.shield.isActive = false
        if pct >= 1.0 {
            habitViewModel.shield.fragments += 1
        } else if pct < 0.5 {
            if habitViewModel.shield.fragments > 0 {
                habitViewModel.shield.fragments -= 1
                habitViewModel.shield.isActive = true
            }
        }
        habitViewModel.save()
    }

    func loadSnapshots() -> [DailySnapshot] {
        guard let data    = UserDefaults.standard.data(forKey: Keys.snapshots),
              let decoded = try? JSONDecoder().decode([DailySnapshot].self, from: data) else {
            return []
        }
        return decoded
    }
}
