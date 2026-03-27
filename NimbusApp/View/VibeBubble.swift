import SwiftUI

struct VibeBubble: View {
    // We pass in the HabitSuggestion data
    let habit: HabitSuggestion
    
    var body: some View {
        VStack(spacing: 8) {
            // 1. The Emoji Hero
            Text(habit.emoji)
                .font(.system(size: 32))
                // Subtle shadow to make emojis pop against dark backgrounds
                .shadow(color: habit.isSelected ? .cyan.opacity(0.5) : .clear, radius: 5)
            
            // 2. The Task Title
            Text(habit.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(habit.isSelected ? .white : .white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(width: 105, height: 105)
        .background(
            ZStack {
                // 3. The Outer Glow (Only visible when selected)
                if habit.isSelected {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .blur(radius: 10)
                }
                
                // 4. The Main Bubble Shape
                Circle()
                    .fill(habit.isSelected ? Color.cyan.opacity(0.25) : Color.white.opacity(0.08))
                    // Frosted glass effect (requires the Blur helper from Screen 1)
                    .background(Blur(style: .systemUltraThinMaterialDark).clipShape(Circle()))
                
                // 5. The Selection Border
                Circle()
                    .stroke(
                        habit.isSelected ? Color.cyan : Color.white.opacity(0.1),
                        lineWidth: habit.isSelected ? 2.5 : 1
                    )
            }
        )
        // 6. The "Juice" (Scaling animation when toggled)
        .scaleEffect(habit.isSelected ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: habit.isSelected)
    }
}
