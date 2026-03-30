import SwiftUI

struct ConstellationView: View {
    @StateObject private var viewModel = ConstellationViewModel()
    var onCompletion: ([String]) -> Void

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

            VStack(spacing: 30) {
                // 1. Nimbos Holding the Map
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

                // 2. Floating Vibe Bubbles
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                        ForEach(viewModel.suggestions) { habit in
                            VibeBubble(habit: habit)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        viewModel.toggleSuggestion(id: habit.id)
                                    }
                                }
                        }
                    }
                    .padding(20)
                }

                // 3. Custom Entry Field
                HStack {
                    TextField("Add a custom star...", text: $viewModel.customTask)
                        .foregroundColor(.white)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 15).fill(.white.opacity(0.1)))

                    Button(action: viewModel.addCustomHabit) {
                        Image(systemName: "plus.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.cyan)
                    }
                }
                .padding(.horizontal, 25)

                // 4. Finalize Button
                if viewModel.hasSelection {
                    Button(action: {
                        onCompletion(viewModel.selectedTitles)
                    }) {
                        Text("IGNITE THE SKY")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(Color.cyan))
                    }
                    .padding(.horizontal, 40)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.bottom, 30)
        }
    }
}
