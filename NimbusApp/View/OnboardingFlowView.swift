import SwiftUI

struct OnboardingFlowView: View {
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            OnboardingBackground(step: viewModel.currentStep, vibe: viewModel.selectedVibe)
                .ignoresSafeArea()

            Group {
                switch viewModel.currentStep {
                case .identity:
                    IdentityView { name in
                        viewModel.setName(name)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

                case .constellation:
                    ConstellationView { habits in
                        viewModel.setHabits(habits)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

                case .vibeCheck:
                    VibeCheckView { vibe in
                        viewModel.setVibe(vibe)
                        // setVibe() saves to UserDefaults and flips nimbus_onboardingComplete.
                        // NimbusAppApp's @AppStorage reacts and swaps to MainDashboardView.
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                }
            }
        }
    }
}

struct OnboardingBackground: View {
    let step: OnboardingStep
    let vibe: VibeType

    @State private var animate = false

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

            Circle()
                .fill(Color.cyan.opacity(0.3))
                .blur(radius: 80)
                .offset(x: animate ? -100 : 100, y: animate ? -200 : -100)

            Circle()
                .fill(vibeColor.opacity(0.2))
                .blur(radius: 100)
                .offset(x: animate ? 100 : -100, y: animate ? 200 : 100)

            Circle()
                .fill(Color.purple.opacity(0.15))
                .blur(radius: 90)
                .offset(x: animate ? 50 : -50, y: animate ? -50 : 50)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }

    private var vibeColor: Color {
        switch step {
        case .identity:     return .gray
        case .constellation: return .blue
        case .vibeCheck:    return vibe == .bestie ? .pink : .indigo
        }
    }
}
