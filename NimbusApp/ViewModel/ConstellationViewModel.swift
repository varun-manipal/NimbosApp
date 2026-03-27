import SwiftUI
import Observation

struct HabitSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let emoji: String
    var isSelected: Bool = false
}

@Observable
class ConstellationViewModel {
    var suggestions: [HabitSuggestion] = [
        HabitSuggestion(title: "Hydrate", emoji: "💧"),
        HabitSuggestion(title: "Meditate", emoji: "🧘"),
        HabitSuggestion(title: "No Screen", emoji: "📱"),
        HabitSuggestion(title: "Move", emoji: "🏃"),
        HabitSuggestion(title: "Read", emoji: "📖"),
        HabitSuggestion(title: "Journal", emoji: "✍️")
    ]
    var customTask: String = ""

    var selectedTitles: [String] {
        suggestions.filter { $0.isSelected }.map { $0.title }
    }

    var hasSelection: Bool {
        suggestions.contains { $0.isSelected }
    }

    func toggleSuggestion(id: UUID) {
        if let index = suggestions.firstIndex(where: { $0.id == id }) {
            suggestions[index].isSelected.toggle()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    func addCustomHabit() {
        guard !customTask.isEmpty else { return }
        suggestions.append(HabitSuggestion(title: customTask, emoji: "✨", isSelected: true))
        customTask = ""
    }
}
