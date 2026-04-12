import SwiftUI

struct OnboardingFlowView: View {
    @StateObject private var viewModel = OnboardingViewModel()

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

                case .roleSelection:
                    RoleSelectionView { role, inviteCode, email in
                        viewModel.setRole(role, inviteCode: inviteCode, email: email)
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
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            }

            // Back button — shown on every step except the first
            if viewModel.currentStep != .identity {
                VStack {
                    HStack {
                        Button(action: viewModel.goBack) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Back")
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.08)))
                        }
                        .padding(.leading, 16)
                        .padding(.top, 56)
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.opacity)
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
        case .identity:      return .gray
        case .roleSelection: return .purple
        case .constellation: return .blue
        case .vibeCheck:     return vibe == .bestie ? .pink : .indigo
        }
    }
}
