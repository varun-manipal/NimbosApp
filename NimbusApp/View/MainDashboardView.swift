import SwiftUI

struct MainDashboardView: View {
    @Bindable var viewModel: HabitViewModel

    // MARK: - Local animation state (UI-only, not in VM)
    @State private var ringScale: CGFloat = 0.05
    @State private var ringOpacity: Double = 0
    @State private var swirlRotation: Double = 0
    @State private var supernovaOpacity: Double = 0
    @State private var supernovaFired: Bool = false
    @State private var showHistory = false
    @State private var showEvolution = false
    @State private var showAura = false

    /// Nimbos floats upward as tasks are completed. Capped at 48pt.
    private var nimbosLiftOffset: CGFloat {
        -min(CGFloat(viewModel.dailyStarsLit) * 8, 48)
    }

    var body: some View {
        ZStack {
            // 1. Violet swirl — appears on 3rd completed task, rotates continuously
            if viewModel.dailyStarsLit >= 3 {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.purple, .cyan, .purple.opacity(0), .purple],
                            center: .center
                        ),
                        lineWidth: 5
                    )
                    .frame(width: 210, height: 210)
                    .rotationEffect(.degrees(swirlRotation))
                    .opacity(0.55)
                    .blur(radius: 3)
                    .allowsHitTesting(false)
                    .transition(.opacity.animation(.easeIn(duration: 0.5)))
            }

            // 3. Cyan heartbeat ring — pulses outward from center on each task completion
            Circle()
                .stroke(Color.cyan.opacity(ringOpacity), lineWidth: 2)
                .scaleEffect(ringScale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // 4. Supernova white flash — fires once when day reaches 100%
            Color.white
                .opacity(supernovaOpacity)
                .blendMode(.screen)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // 5. Main HUD
            VStack(spacing: 0) {
                StarShardHeader(
                    totalStarsLit: viewModel.totalStarsLit,
                    progress: viewModel.totalProgress
                )
                .padding(.top, 60)

                // Navigation icons
                HStack(spacing: 20) {
                    Spacer()
                    NavIconButton(icon: "calendar", label: "History") { showHistory = true }
                    NavIconButton(icon: "chart.line.uptrend.xyaxis", label: "Evolution") { showEvolution = true }
                    NavIconButton(icon: "square.and.arrow.up", label: "Aura") { showAura = true }
                    Spacer()
                }
                .padding(.top, 16)

                Spacer()

                // Dialogue — shield message takes priority over vibe dialogue
                if let dialogue = viewModel.shieldDialogue ?? viewModel.nimbosDialogue {
                    NimbosDialogueCard(text: dialogue)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Checklist panel
                VStack(alignment: .leading, spacing: 15) {
                    Text("Today's Tasks")
                        .font(.system(.caption))
                        .foregroundColor(.cyan)
                        .tracking(2)

                    ForEach($viewModel.tasks) { $task in
                        if !task.isSnoozed {
                            TaskHUDRow(
                                task: $task,
                                onToggle:  { viewModel.toggleTask(task)  },
                                onSnooze:  { viewModel.snoozeTask(task)  },
                                onDismiss: { viewModel.dismissTask(task) }
                            )
                        }
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial.opacity(0.2))
                .cornerRadius(24)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .shadow(color: .black.opacity(0.3), radius: 20)
            }

            // 6. Morning Mist overlay — first open of a new day
            if viewModel.showMorningMist {
                MorningMistOverlay(userName: viewModel.userName) {
                    withAnimation(.easeOut(duration: 0.8)) {
                        viewModel.showMorningMist = false
                    }
                }
                .transition(.opacity)
            }

            // 7. Milestone video — plays when totalStarsLit hits 12
            if viewModel.showMilestoneVideo {
                MilestoneVideoOverlay {
                    withAnimation(.easeOut(duration: 0.4)) {
                        viewModel.showMilestoneVideo = false
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .background {
            GeometryReader { geo in
                Image(viewModel.nimbosStateImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                    .clipped()
                    .scaleEffect(1.05)
                    .offset(y: nimbosLiftOffset)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.dailyStarsLit)
                    .overlay(glowOverlay)
                    .overlay(shieldSphere)
                    .animation(.easeInOut(duration: 0.8), value: viewModel.nimbosStateImage)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            // Kick off the continuous swirl rotation once
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                swirlRotation = 360
            }
        }
        .onChange(of: viewModel.lastCompletedId) { _, id in
            if id != nil { triggerRingPulse() }
        }
        .onChange(of: viewModel.dailyCompletionPercentage) { _, pct in
            if pct >= 1.0, !supernovaFired {
                supernovaFired = true
                triggerSupernova()
            } else if pct < 1.0 {
                supernovaFired = false   // allow re-fire if tasks are later un-toggled
            }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(totalStarsLit: viewModel.totalStarsLit)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEvolution) {
            EvolutionTimelineView(totalStarsLit: viewModel.totalStarsLit)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAura) {
            AuraCardView(
                totalStarsLit: viewModel.totalStarsLit,
                userName: viewModel.userName,
                nimbosStateImage: viewModel.nimbosStateImage
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Glow Overlay

    @ViewBuilder
    private var glowOverlay: some View {
        ZStack {
            // Grows steadily as tasks are completed
            Color.cyan
                .opacity(0.12 * viewModel.dailyCompletionPercentage)
                .blendMode(.screen)
                .animation(.easeOut(duration: 0.5), value: viewModel.dailyCompletionPercentage)

            // Brief pulse flash on each completion
            Color.cyan
                .opacity(viewModel.lastCompletedId != nil ? 0.25 : 0)
                .blendMode(.screen)
                .animation(.easeOut(duration: 0.4), value: viewModel.lastCompletedId == nil)

            // Sustained High Glow at 100% — stays until midnight
            if viewModel.dailyCompletionPercentage >= 1.0 {
                Color.cyan
                    .opacity(0.3)
                    .blendMode(.screen)
                    .transition(.opacity.animation(.easeIn(duration: 0.8)))
            }
        }
    }

    // MARK: - Shield Sphere

    @ViewBuilder
    private var shieldSphere: some View {
        if viewModel.shield.isActive {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.cyan.opacity(0.6), .cyan.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 3
                )
                .frame(width: 260, height: 260)
                .blur(radius: 4)
                .allowsHitTesting(false)
                .transition(.opacity.animation(.easeIn(duration: 0.8)))
        }
    }

    // MARK: - Animation Triggers

    private func triggerRingPulse() {
        ringScale   = 0.05
        ringOpacity = 0.9
        withAnimation(.easeOut(duration: 0.75)) {
            ringScale   = 2.8
            ringOpacity = 0
        }
    }

    private func triggerSupernova() {
        withAnimation(.easeIn(duration: 0.12)) { supernovaOpacity = 0.85 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 1.1)) { supernovaOpacity = 0 }
        }
    }
}

// MARK: - Nimbos Dialogue Card

struct NimbosDialogueCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("☁️").font(.system(size: 22))
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.6))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 8)
    }
}

// MARK: - Morning Mist Overlay

struct MorningMistOverlay: View {
    let userName: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("☁️").font(.system(size: 72))
                Text("The stars have faded.")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Let's relight the sky\(userName.isEmpty ? "" : ", \(userName)").")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { onDismiss() }
        }
    }
}

// MARK: - Star Shard Header

struct StarShardHeader: View {
    let totalStarsLit: Int
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(totalStarsLit) Star Shards")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                Spacer()
                Image(systemName: "sparkles")
            }
            .foregroundColor(.white)

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1)).frame(height: 6)
                Capsule()
                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                    .frame(width: UIScreen.main.bounds.width * 0.85 * CGFloat(progress), height: 6)
                    .shadow(color: .cyan.opacity(0.6), radius: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progress)
            }
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Task HUD Row

struct TaskHUDRow: View {
    @Binding var task: HabitTask
    var onToggle:  () -> Void
    var onSnooze:  () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack {
            Text(task.title)
                .font(.system(.body, design: .rounded))
                .foregroundColor(rowTextColor)
                .strikethrough(task.isDismissedToday, color: .white.opacity(0.2))

            Spacer()

            if task.isDismissedToday {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.2))
            } else {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        onToggle()
                    }
                }) {
                    ZStack {
                        Circle()
                            .stroke(task.isCompleted ? Color.cyan : Color.white.opacity(0.2), lineWidth: 2)
                            .frame(width: 28, height: 28)
                        if task.isCompleted {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.cyan)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !task.isCompleted && !task.isDismissedToday {
                Button {
                    withAnimation { onSnooze() }
                } label: {
                    Label("Snooze", systemImage: "moon.zzz.fill")
                }
                .tint(.indigo)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if !task.isDismissedToday {
                Button {
                    withAnimation { onDismiss() }
                } label: {
                    Label("Dismiss", systemImage: "xmark.circle.fill")
                }
                .tint(.gray)
            }
        }
    }

    private var rowTextColor: Color {
        if task.isDismissedToday { return .white.opacity(0.25) }
        if task.isCompleted      { return .white.opacity(0.4)  }
        return .white
    }
}

// MARK: - Nav Icon Button

struct NavIconButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial.opacity(0.3))
                    .clipShape(Circle())
                Text(label)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1)
            }
        }
    }
}
