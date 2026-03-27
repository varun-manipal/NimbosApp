import Foundation
import Observation

@Observable
class HistoryViewModel {
    var snapshots: [DailySnapshot] = []
    var selectedSnapshot: DailySnapshot? = nil
    var displayMonth: Date = Calendar.current.startOfDay(for: Date())

    init() {
        reload()
    }

    func reload() {
        snapshots = DailyRefreshViewModel().loadSnapshots()
    }

    // MARK: - Month Navigation

    var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayMonth)
    }

    var canGoNext: Bool {
        let cal = Calendar.current
        guard let next = cal.date(byAdding: .month, value: 1, to: displayMonth) else { return false }
        return cal.compare(next, to: Date(), toGranularity: .month) != .orderedDescending
    }

    func previousMonth() {
        displayMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
    }

    func nextMonth() {
        guard canGoNext else { return }
        displayMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
    }

    // MARK: - Grid

    /// Ordered dates for the display month, nil = blank padding cell
    var monthDays: [Date?] {
        let cal  = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: displayMonth)
        guard let first = cal.date(from: comps) else { return [] }

        let leadingBlanks = (cal.component(.weekday, from: first) - 1 + 7) % 7
        let count = cal.range(of: .day, in: .month, for: first)!.count

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in 1...count {
            var dc = comps; dc.day = day
            days.append(cal.date(from: dc))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    func snapshot(for date: Date) -> DailySnapshot? {
        let cal = Calendar.current
        return snapshots.first { cal.isDate($0.date, inSameDayAs: date) }
    }

    func isFuture(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Nimbos image name to use as background for a selected snapshot
    func backgroundImage(for snapshot: DailySnapshot) -> String {
        switch snapshot.completionPercentage {
        case 1.0:        return "Nimbos Stage 4"
        case 0.5...:     return "Nimbos Stage 3"
        case 0.01...:    return "Nimbos Stage 2"
        default:         return "Nimbos Stage 1"
        }
    }
}
