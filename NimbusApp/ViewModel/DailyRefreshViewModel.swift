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

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Call this whenever the app enters the foreground.
    /// Sends the last-opened date to the service and applies any new-day reset it returns.
    /// Falls back to local logic if the service is unavailable.
    func checkForNewDay(habitViewModel: HabitViewModel) {
        let today = Calendar.current.startOfDay(for: Date())
        let todayStr = dateFormatter.string(from: today)

        // Determine the last-opened date string to send to the service.
        let lastOpenedStr: String
        if let stored = UserDefaults.standard.string(forKey: Keys.lastOpenedDate) {
            lastOpenedStr = stored
        } else {
            // First ever open — record today and leave tasks untouched.
            UserDefaults.standard.set(todayStr, forKey: Keys.lastOpenedDate)
            lastOpenedStr = todayStr
        }

        guard APIClient.shared.isRegistered else {
            checkForNewDayLocally(habitViewModel: habitViewModel, today: today, todayStr: todayStr, lastOpenedStr: lastOpenedStr)
            return
        }

        Task {
            do {
                let response = try await APIClient.shared.newDay(lastOpenedDate: lastOpenedStr)
                await MainActor.run {
                    if response.wasNewDay {
                        habitViewModel.tasks         = response.tasks.map { HabitTask(from: $0) }
                        habitViewModel.tomorrowExtras = []
                        habitViewModel.dailyStarsLit = 0
                        habitViewModel.shield        = Shield(from: response.shield)
                        habitViewModel.save()
                        habitViewModel.showMorningMist = true
                    }
                    UserDefaults.standard.set(todayStr, forKey: Keys.lastOpenedDate)
                }
            } catch {
                // Service unavailable — fall back to local reset logic
                await MainActor.run {
                    self.checkForNewDayLocally(habitViewModel: habitViewModel,
                                               today: today,
                                               todayStr: todayStr,
                                               lastOpenedStr: lastOpenedStr)
                }
            }
        }
    }

    // MARK: - Local fallback

    private func checkForNewDayLocally(habitViewModel: HabitViewModel,
                                       today: Date,
                                       todayStr: String,
                                       lastOpenedStr: String) {
        guard let lastOpened = dateFormatter.date(from: lastOpenedStr),
              !Calendar.current.isDate(lastOpened, inSameDayAs: today) else {
            return
        }

        archiveSnapshotLocally(for: habitViewModel, date: lastOpened)

        for i in habitViewModel.tasks.indices {
            habitViewModel.tasks[i].isCompleted       = false
            habitViewModel.tasks[i].isSnoozed         = habitViewModel.tasks[i].isSkippedTomorrow
            habitViewModel.tasks[i].isSkippedTomorrow = false
            habitViewModel.tasks[i].isDismissedToday  = false
        }

        habitViewModel.tasks.append(contentsOf: habitViewModel.tomorrowExtras)
        habitViewModel.tomorrowExtras = []
        habitViewModel.dailyStarsLit  = 0
        habitViewModel.save()

        UserDefaults.standard.set(todayStr, forKey: Keys.lastOpenedDate)
        habitViewModel.showMorningMist = true
    }

    private func archiveSnapshotLocally(for habitViewModel: HabitViewModel, date: Date) {
        let pct = habitViewModel.dailyCompletionPercentage
        let snapshot = DailySnapshot(
            date: date,
            completionPercentage: pct,
            starsLit: habitViewModel.dailyStarsLit
        )
        var all = loadSnapshots()
        all.append(snapshot)
        if let encoded = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(encoded, forKey: Keys.snapshots)
        }

        // Shield logic (local fallback — server uses 80% threshold)
        habitViewModel.shield.isActive = false
        if pct >= 1.0 {
            habitViewModel.shield.fragments += 1
        } else if pct < 0.5, habitViewModel.shield.fragments > 0 {
            habitViewModel.shield.fragments -= 1
            habitViewModel.shield.isActive = true
        }
        habitViewModel.save()
    }

    // MARK: - Snapshot persistence (local cache)

    func loadSnapshots() -> [DailySnapshot] {
        guard let data    = UserDefaults.standard.data(forKey: Keys.snapshots),
              let decoded = try? JSONDecoder().decode([DailySnapshot].self, from: data) else {
            return []
        }
        return decoded
    }
}
