import SwiftUI
import AudioToolbox

// MARK: - Confetti particle

private struct Particle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let color: Color
    let size: CGFloat
    let shape: ParticleShape
    let xDrift: CGFloat
    var opacity: Double = 1
}

private enum ParticleShape { case circle, star, rect }

// MARK: - Milestone metadata

private let milestoneInfo: [Int: (title: String, emoji: String, gradient: [Color])] = [
    12:  ("The Spark",     "✨", [.yellow, .orange]),
    35:  ("The Float",     "🌊", [.cyan, .blue]),
    50:  ("Soft Ignition", "🔥", [.orange, .pink]),
    100: ("The Ancient",   "⚡️", [.purple, .indigo]),
]

// MARK: - Main view

struct AwardClaimView: View {
    let award: MilestoneAwardDTO
    let onClaim: (Int) -> Void
    let onDismiss: () -> Void

    @State private var selectedIndex: Int? = nil
    @State private var headerScale: CGFloat = 0.4
    @State private var headerOpacity: Double = 0
    @State private var cardsOffset: CGFloat = 60
    @State private var cardsOpacity: Double = 0
    @State private var particles: [Particle] = []
    @State private var particlesActive = false
    @State private var claimBounce: CGFloat = 1.0

    private var info: (title: String, emoji: String, gradient: [Color]) {
        milestoneInfo[award.milestoneShards] ?? ("Milestone", "🎉", [.purple, .cyan])
    }

    private var awards: [(index: Int, text: String)] {
        [(1, award.award1), (2, award.award2), (3, award.award3)]
            .compactMap { idx, text in text.map { (idx, $0) } }
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    info.gradient[0].opacity(0.25),
                    Color.black,
                    info.gradient[1].opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Confetti layer
            ForEach(particles) { p in
                ConfettiPiece(particle: p, isActive: particlesActive)
            }

            // Content
            VStack(spacing: 0) {
                Spacer()

                // Header
                VStack(spacing: 10) {
                    Text(info.emoji)
                        .font(.system(size: 72))
                        .shadow(color: info.gradient[0], radius: 20)

                    Text("You did it!")
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, info.gradient[0]],
                                           startPoint: .leading, endPoint: .trailing)
                        )

                    Text(info.title)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: info.gradient,
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: info.gradient[0].opacity(0.6), radius: 12)

                    Text("\(award.milestoneShards) Star Shards collected!")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.1)))
                }
                .scaleEffect(headerScale)
                .opacity(headerOpacity)
                .padding(.bottom, 32)

                // Pick your reward
                VStack(spacing: 14) {
                    Text("🎁 Pick your reward!")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundColor(.white)

                    VStack(spacing: 10) {
                        ForEach(awards, id: \.index) { item in
                            AwardOptionCard(
                                text: item.text,
                                index: item.index,
                                isSelected: selectedIndex == item.index,
                                gradient: info.gradient
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    selectedIndex = item.index
                                }
                                AudioServicesPlaySystemSound(1057)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                }
                .offset(y: cardsOffset)
                .opacity(cardsOpacity)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        guard let idx = selectedIndex else { return }
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                            claimBounce = 1.15
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                claimBounce = 1.0
                            }
                        }
                        AudioServicesPlaySystemSound(1322)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onClaim(idx)
                        }
                    } label: {
                        Text(selectedIndex != nil ? "🎊 Claim This Reward!" : "Choose one above first")
                            .font(.system(.headline, design: .rounded).weight(.heavy))
                            .foregroundColor(selectedIndex != nil ? .black : .white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                Group {
                                    if selectedIndex != nil {
                                        LinearGradient(colors: info.gradient,
                                                       startPoint: .leading, endPoint: .trailing)
                                    } else {
                                        LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.12)],
                                                       startPoint: .leading, endPoint: .trailing)
                                    }
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: selectedIndex != nil ? info.gradient[0].opacity(0.5) : .clear, radius: 12)
                    }
                    .disabled(selectedIndex == nil)
                    .scaleEffect(claimBounce)
                    .padding(.horizontal, 28)

                    Button("I'll decide later") {
                        onDismiss()
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.bottom, 8)
                }
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            playCelebrationSound()
            spawnParticles()

            withAnimation(.spring(response: 0.5, dampingFraction: 0.65).delay(0.1)) {
                headerScale = 1.0
                headerOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.35)) {
                cardsOffset = 0
                cardsOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 1.8)) {
                    particlesActive = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func playCelebrationSound() {
        // Quick ascending fanfare using two system sounds with a short delay
        AudioServicesPlaySystemSound(1016)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            AudioServicesPlaySystemSound(1322)
        }
    }

    private func spawnParticles() {
        let colors: [Color] = info.gradient + [.white, .yellow, .pink, .cyan, .green]
        let shapes: [ParticleShape] = [.circle, .star, .rect]
        particles = (0..<60).map { _ in
            Particle(
                x: CGFloat.random(in: 0.05...0.95),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 5...13),
                shape: shapes.randomElement()!,
                xDrift: CGFloat.random(in: -80...80)
            )
        }
    }
}

// MARK: - Award option card

private struct AwardOptionCard: View {
    let text: String
    let index: Int
    let isSelected: Bool
    let gradient: [Color]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.12)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 36, height: 36)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(.black)
                    } else {
                        Text("\(index)")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Text(text)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                    .multilineTextAlignment(.leading)

                Spacer()

                if isSelected {
                    Image(systemName: "star.fill")
                        .foregroundStyle(
                            LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom)
                        )
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected
                          ? LinearGradient(colors: gradient.map { $0.opacity(0.22) },
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [.white.opacity(0.07), .white.opacity(0.07)],
                                           startPoint: .leading, endPoint: .trailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected
                                ? LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.12)], startPoint: .leading, endPoint: .trailing),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .shadow(color: isSelected ? gradient[0].opacity(0.35) : .clear, radius: 10)
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - Confetti piece

private struct ConfettiPiece: View {
    let particle: Particle
    let isActive: Bool

    var body: some View {
        GeometryReader { geo in
            Group {
                switch particle.shape {
                case .circle:
                    Circle().fill(particle.color)
                case .star:
                    Image(systemName: "star.fill")
                        .resizable()
                        .foregroundColor(particle.color)
                case .rect:
                    RoundedRectangle(cornerRadius: 2).fill(particle.color)
                }
            }
            .frame(width: particle.size, height: particle.size)
            .opacity(isActive ? 0 : particle.opacity)
            .offset(
                x: geo.size.width * particle.x + (isActive ? particle.xDrift : 0),
                y: isActive ? geo.size.height + 40 : -20
            )
        }
        .allowsHitTesting(false)
    }
}
