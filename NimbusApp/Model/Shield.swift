import Foundation

struct Shield: Codable {
    var fragments: Int = 0   // earned from 100% days — never goes below 0
    var isActive: Bool = false  // true when a fragment was consumed on the previous missed day
}
