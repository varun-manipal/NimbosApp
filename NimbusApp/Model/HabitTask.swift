import Foundation

struct HabitTask: Identifiable, Codable {
    let id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var isSnoozed: Bool = false          // excluded from today; resets at dawn
    var isDismissedToday: Bool = false   // shown grayed out; not counted; resets at dawn
    var lastUpdated: Date = Date()
}
