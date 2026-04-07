import SwiftUI

struct ConstellationView: View {
    @StateObject private var viewModel = ConstellationViewModel()
    var onCompletion: ([String]) -> Void

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

            // Rainbow sparkle particles
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                RainbowSparkle(x: w * 0.10, y: h * 0.08, size: 10, color: .red,    duration: 3.1, delay: 0.0)
                RainbowSparkle(x: w * 0.82, y: h * 0.06, size:  7, color: .orange,  duration: 2.7, delay: 0.5)
                RainbowSparkle(x: w * 0.55, y: h * 0.14, size: 13, color: .yellow,  duration: 3.5, delay: 1.0)
                RainbowSparkle(x: w * 0.22, y: h * 0.28, size:  8, color: .green,   duration: 2.9, delay: 0.3)
                RainbowSparkle(x: w * 0.90, y: h * 0.32, size: 11, color: .cyan,    duration: 3.3, delay: 0.8)
                RainbowSparkle(x: w * 0.06, y: h * 0.52, size:  9, color: .blue,    duration: 2.6, delay: 1.3)
                RainbowSparkle(x: w * 0.72, y: h * 0.58, size: 12, color: .purple,  duration: 3.7, delay: 0.2)
                RainbowSparkle(x: w * 0.38, y: h * 0.70, size:  7, color: .pink,    duration: 2.8, delay: 0.7)
                RainbowSparkle(x: w * 0.88, y: h * 0.76, size: 10, color: .red,     duration: 3.2, delay: 1.1)
                RainbowSparkle(x: w * 0.15, y: h * 0.88, size:  8, color: .orange,  duration: 3.0, delay: 0.4)
                RainbowSparkle(x: w * 0.60, y: h * 0.92, size: 11, color: .yellow,  duration: 2.5, delay: 0.9)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    Text("☁️")
                        .font(.system(size: 60))
                        .shadow(color: .cyan, radius: 10)

                    Text("What stars are we lighting up?")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Choose 3-5 anchors for your daily sky.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)

                // Habit list with auto-scroll to last added
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.suggestions) { habit in
                                HabitRow(habit: habit)
                                    .id(habit.id)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                            viewModel.toggleSuggestion(id: habit.id)
                                        }
                                    }

                                Divider()
                                    .background(Color.white.opacity(0.08))
                                    .padding(.leading, 68)
                            }
                        }
                    }
                    .onChange(of: viewModel.suggestions.count) { _ in
                        if let last = viewModel.suggestions.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Finalize button
                if viewModel.hasSelection {
                    Button(action: { onCompletion(viewModel.selectedTitles) }) {
                        Text("IGNITE THE SKY")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(Color.cyan))
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        // Text field pinned above the keyboard
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                TextField("Add a custom star...", text: $viewModel.customTask)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .submitLabel(.done)
                    .onSubmit { viewModel.addCustomHabit() }

                Button(action: viewModel.addCustomHabit) {
                    Image(systemName: "plus.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.cyan)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(red: 0.05, green: 0.05, blue: 0.1))
        }
    }
}

// MARK: - Rainbow Sparkle Particle

private struct RainbowSparkle: View {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let color: Color
    let duration: Double
    let delay: Double

    @State private var bobOffset: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.6

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .thin))
            .foregroundStyle(color.opacity(0.8))
            .shadow(color: color.opacity(0.6), radius: 4)
            .position(x: x, y: y)
            .offset(y: bobOffset)
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeOut(duration: 0.7).delay(delay)) {
                    opacity = Double.random(in: 0.5...0.9)
                    scale = 1.0
                }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) {
                    bobOffset = -14
                }
            }
    }
}

// MARK: - Habit Row

private struct HabitRow: View {
    let habit: HabitSuggestion

    var body: some View {
        HStack(spacing: 16) {
            // Emoji badge
            Text(habit.emoji)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(habit.isSelected ? Color.cyan.opacity(0.2) : Color.white.opacity(0.07))
                )
                .overlay(
                    Circle()
                        .stroke(habit.isSelected ? Color.cyan.opacity(0.6) : Color.clear, lineWidth: 1.5)
                )

            Text(habit.title)
                .font(.system(.body, design: .rounded))
                .foregroundColor(habit.isSelected ? .white : .white.opacity(0.7))

            Spacer()

            // Selection indicator
            Image(systemName: habit.isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundColor(habit.isSelected ? .cyan : .white.opacity(0.2))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(habit.isSelected ? Color.cyan.opacity(0.06) : Color.clear)
        .animation(.easeInOut(duration: 0.15), value: habit.isSelected)
    }
}
