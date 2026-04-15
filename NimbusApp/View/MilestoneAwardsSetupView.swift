import SwiftUI

struct MilestoneAwardsSetupView: View {
    let child: ChildProgressDTO
    @Environment(\.dismiss) private var dismiss

    private let milestones: [(shards: Int, title: String, color: Color)] = [
        (12,  "The Spark",     .yellow),
        (35,  "The Float",     .cyan),
        (50,  "Soft Ignition", .orange),
        (100, "The Ancient",   .purple),
    ]

    @State private var awardInputs: [Int: [String]] = [:]
    @State private var claimedTexts: [Int: String] = [:]   // milestoneShards → claimed award text
    @State private var savedMilestones: Set<Int> = []
    @State private var failedMessages: [Int: String] = [:]
    @State private var expandedMilestone: Int? = nil
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(milestones, id: \.shards) { milestone in
                                MilestoneAwardSection(
                                    milestone: milestone,
                                    awards: Binding(
                                        get: { awardInputs[milestone.shards] ?? ["", "", ""] },
                                        set: { awardInputs[milestone.shards] = $0 }
                                    ),
                                    claimedText: claimedTexts[milestone.shards],
                                    isSaved: savedMilestones.contains(milestone.shards),
                                    failedMessage: failedMessages[milestone.shards],
                                    isExpanded: expandedMilestone == milestone.shards,
                                    onToggle: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            expandedMilestone = expandedMilestone == milestone.shards ? nil : milestone.shards
                                        }
                                    },
                                    onSave: {
                                        Task { await save(milestoneShards: milestone.shards) }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Awards for \(child.name)")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.purple)
                }
            }
            .task { await loadAwards() }
        }
    }

    // MARK: - Data

    private func loadAwards() async {
        isLoading = true
        do {
            let awards = try await APIClient.shared.getChildAwards(childId: child.userId)
            var inputs: [Int: [String]] = [:]
            var claimed: [Int: String] = [:]
            for award in awards {
                inputs[award.milestoneShards] = [
                    award.award1 ?? "",
                    award.award2 ?? "",
                    award.award3 ?? ""
                ]
                if let text = award.claimedAwardText {
                    claimed[award.milestoneShards] = text
                }
            }
            awardInputs = inputs
            claimedTexts = claimed
        } catch {
            print("[MilestoneAwards] loadAwards failed: \(error)")
        }
        isLoading = false
    }

    private func save(milestoneShards: Int) async {
        let inputs = awardInputs[milestoneShards] ?? ["", "", ""]
        let a1 = inputs.count > 0 && !inputs[0].isEmpty ? inputs[0] : nil
        let a2 = inputs.count > 1 && !inputs[1].isEmpty ? inputs[1] : nil
        let a3 = inputs.count > 2 && !inputs[2].isEmpty ? inputs[2] : nil

        do {
            let updated = try await APIClient.shared.setChildAward(
                childId: child.userId,
                milestoneShards: milestoneShards,
                award1: a1, award2: a2, award3: a3
            )
            awardInputs[milestoneShards] = [
                updated.award1 ?? "",
                updated.award2 ?? "",
                updated.award3 ?? ""
            ]
            failedMessages[milestoneShards] = nil
            savedMilestones.insert(milestoneShards)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                savedMilestones.remove(milestoneShards)
            }
        } catch {
            print("[MilestoneAwards] save(\(milestoneShards)) failed: \(error)")
            let msg: String
            if case APIError.httpError(let code) = error {
                msg = "Error \(code)"
            } else if case APIError.decodingError(let e) = error {
                msg = "Decode error: \(e)"
            } else {
                msg = "Network error"
            }
            failedMessages[milestoneShards] = msg
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                failedMessages[milestoneShards] = nil
            }
        }
    }
}

// MARK: - Section

private struct MilestoneAwardSection: View {
    let milestone: (shards: Int, title: String, color: Color)
    @Binding var awards: [String]
    let claimedText: String?
    let isSaved: Bool
    let failedMessage: String?
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSave: () -> Void

    private var hasAnyAward: Bool { awards.contains(where: { !$0.isEmpty }) }
    private var isClaimed: Bool { claimedText != nil }

    var body: some View {
        VStack(spacing: 0) {
            // Header row — not tappable when claimed
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(milestone.title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundColor(isClaimed ? milestone.color.opacity(0.5) : milestone.color)
                    Text("\(milestone.shards) shards")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
                Spacer()
                if isClaimed {
                    Label("Claimed", systemImage: "checkmark.seal.fill")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundColor(milestone.color.opacity(0.6))
                } else {
                    if awards.contains(where: { !$0.isEmpty }) && !isExpanded {
                        Circle()
                            .fill(milestone.color)
                            .frame(width: 7, height: 7)
                            .padding(.trailing, 4)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture { if !isClaimed { onToggle() } }

            if isClaimed, let text = claimedText {
                Divider().background(Color.white.opacity(0.06))
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 13))
                        .foregroundColor(milestone.color.opacity(0.5))
                    Text(text)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else if isExpanded {
                Divider().background(Color.white.opacity(0.08))

                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { i in
                        HStack {
                            Text("Award \(i + 1)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(width: 60, alignment: .leading)
                            TextField("e.g. Pizza night", text: Binding(
                                get: { awards.count > i ? awards[i] : "" },
                                set: {
                                    while awards.count <= i { awards.append("") }
                                    awards[i] = $0
                                }
                            ))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.white.opacity(0.07))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            )
                        }
                    }

                    Button(action: onSave) {
                        HStack(spacing: 6) {
                            if let msg = failedMessage {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(msg)
                            } else if isSaved {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Saved!")
                            } else {
                                Text("Save Awards")
                            }
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(failedMessage != nil ? .red : isSaved ? milestone.color : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    failedMessage != nil ? Color.red.opacity(0.15) :
                                    isSaved              ? milestone.color.opacity(0.15) :
                                                           milestone.color.opacity(0.25)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            failedMessage != nil ? Color.red.opacity(0.5) : milestone.color.opacity(0.4),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .disabled(!hasAnyAward)
                    .opacity(hasAnyAward ? 1 : 0.45)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isClaimed ? .white.opacity(0.02) : .white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                    isClaimed ? Color.white.opacity(0.04) : Color.white.opacity(0.08),
                    lineWidth: 1
                ))
        )
        .opacity(isClaimed ? 0.75 : 1.0)
    }
}
