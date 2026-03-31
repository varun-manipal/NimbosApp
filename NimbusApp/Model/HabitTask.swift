import Foundation

struct HabitTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool = false
    var isSnoozed: Bool = false          // excluded from today; resets at dawn
    var isDismissedToday: Bool = false   // shown grayed out; not counted; resets at dawn
    var isSkippedTomorrow: Bool = false  // user-planned skip; converted to isSnoozed at next dawn
    var lastUpdated: Date = Date()

    init(title: String) {
        self.id = UUID()
        self.title = title
    }

    // Custom decoder for backward compatibility — isSkippedTomorrow is a new field
    // and may be absent in data saved by older versions of the app.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decodeIfPresent(UUID.self,   forKey: .id)               ?? UUID()
        title            = try c.decode(String.self,          forKey: .title)
        isCompleted      = try c.decodeIfPresent(Bool.self,   forKey: .isCompleted)      ?? false
        isSnoozed        = try c.decodeIfPresent(Bool.self,   forKey: .isSnoozed)        ?? false
        isDismissedToday = try c.decodeIfPresent(Bool.self,   forKey: .isDismissedToday) ?? false
        isSkippedTomorrow = try c.decodeIfPresent(Bool.self,  forKey: .isSkippedTomorrow) ?? false
        lastUpdated      = try c.decodeIfPresent(Date.self,   forKey: .lastUpdated)      ?? Date()
    }
}
