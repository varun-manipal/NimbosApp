import SwiftUI

private struct Milestone {
    let shards: Int
    let title: String
    let subtitle: String
    let imageName: String
    let accentColor: Color
}

private let allMilestones: [Milestone] = [
    Milestone(shards: 12,  title: "The Spark",     subtitle: "First glow of change",   imageName: "Nimbos Stage 2", accentColor: .yellow),
    Milestone(shards: 35,  title: "The Float",     subtitle: "Rising above the fog",   imageName: "Nimbos Stage 3", accentColor: .cyan),
    Milestone(shards: 50,  title: "Soft Ignition", subtitle: "The sky begins to burn", imageName: "Nimbos Stage 4", accentColor: .orange),
    Milestone(shards: 100, title: "The Ancient",   subtitle: "Beyond the horizon",     imageName: "Nimbos Stage 4", accentColor: .purple),
]

struct EvolutionTimelineView: View {
    let totalStarsLit: Int
    /// Seed value shown immediately. View fetches fresh data independently.
    var initialAwards: [MilestoneAwardDTO] = []
    /// Called when the child taps "Claim Award" on a milestone card.
    var onClaimAward: ((MilestoneAwardDTO) -> Void)? = nil
    /// Async closure that fetches fresh awards without side effects.
    var fetchAwards: (() async -> [MilestoneAwardDTO])? = nil

    @State private var awards: [MilestoneAwardDTO] = []

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image(currentStageImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("Evolution")
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("\(totalStarsLit) Star Shards collected")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.cyan)
                }
                .padding(.top, 60)
                .padding(.bottom, 32)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(allMilestones, id: \.shards) { milestone in
                            let award = awards.first(where: { $0.milestoneShards == milestone.shards })
                            MilestoneCard(
                                milestone: milestone,
                                isUnlocked: totalStarsLit >= milestone.shards,
                                isCurrent: currentMilestone?.shards == milestone.shards,
                                award: award,
                                onClaimAward: onClaimAward
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                }

                Spacer()

                if let next = nextMilestone {
                    VStack(spacing: 8) {
                        Text("Next: \(next.title) at \(next.shards) shards")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.1)).frame(height: 6)
                                Capsule()
                                    .fill(LinearGradient(colors: [.cyan, next.accentColor],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * CGFloat(progressToNext), height: 6)
                                    .shadow(color: .cyan.opacity(0.5), radius: 6)
                            }
                        }
                        .frame(height: 6)
                        .padding(.horizontal, 30)
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            // Show cached data immediately so the view isn't blank
            if awards.isEmpty { awards = initialAwards }
        }
        .task {
            // Fetch fresh data in the background; update local state when ready
            if let fetch = fetchAwards {
                awards = await fetch()
            }
        }
    }

    private var currentStageImage: String {
        if totalStarsLit < 12 { return "Nimbos Stage 1" }
        if totalStarsLit < 35 { return "Nimbos Stage 2" }
        if totalStarsLit < 50 { return "Nimbos Stage 3" }
        return "Nimbos Stage 4"
    }

    private var currentMilestone: Milestone? {
        allMilestones.filter { totalStarsLit >= $0.shards }.last
    }

    private var nextMilestone: Milestone? {
        allMilestones.first { totalStarsLit < $0.shards }
    }

    private var progressToNext: Double {
        guard let next = nextMilestone else { return 1.0 }
        let prev = allMilestones.last(where: { $0.shards <= totalStarsLit })?.shards ?? 0
        let range = next.shards - prev
        let earned = totalStarsLit - prev
        return min(Double(earned) / Double(range), 1.0)
    }
}

// MARK: - Milestone Card

private struct MilestoneCard: View {
    let milestone: Milestone
    let isUnlocked: Bool
    let isCurrent: Bool
    var award: MilestoneAwardDTO? = nil
    var onClaimAward: ((MilestoneAwardDTO) -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Image(milestone.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 200)
                    .clipped()
                    .cornerRadius(20)
                    .saturation(isUnlocked ? 1.0 : 0.0)
                    .opacity(isUnlocked ? 1.0 : 0.35)

                if !isUnlocked {
                    VStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.6))
                        Text("\(milestone.shards) shards")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                if isCurrent {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(colors: [milestone.accentColor, .cyan],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 3
                        )
                        .frame(width: 160, height: 200)
                }
            }

            VStack(spacing: 4) {
                Text(milestone.title)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(isUnlocked ? .white : .white.opacity(0.35))
                Text(milestone.subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(isUnlocked ? milestone.accentColor : .white.opacity(0.2))

                if isUnlocked, let award = award {
                    if let claimedText = award.claimedAwardText {
                        Text("✓ \(claimedText)")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundColor(milestone.accentColor)
                            .multilineTextAlignment(.center)
                            .padding(.top, 2)
                    } else if award.hasAwards, let onClaim = onClaimAward {
                        Button {
                            onClaim(award)
                        } label: {
                            Label("Claim Award", systemImage: "gift.fill")
                                .font(.system(.caption2, design: .rounded).weight(.semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().fill(milestone.accentColor)
                                )
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .frame(width: 160)
    }
}
