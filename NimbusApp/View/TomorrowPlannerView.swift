import SwiftUI

struct TomorrowPlannerView: View {
    @ObservedObject var viewModel: HabitViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newExtraTitle = ""
    @State private var showConfirmation = false
    @FocusState private var isAddFieldFocused: Bool

    private var tomorrowDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return formatter.string(from: tomorrow)
    }

    var body: some View {
        ZStack {
            // Background — mirrors the dashboard
            GeometryReader { geo in
                Image(viewModel.nimbosStateImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                    .clipped()
            }
            .ignoresSafeArea()

            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tomorrow's Sky")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                        Text(tomorrowDateString.uppercased())
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.8))
                            .tracking(1.5)
                    }
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 20) {
                        // SECTION 1: Recurring habits
                        if !viewModel.tasks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("YOUR ANCHORS")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .tracking(2)
                                    .padding(.horizontal, 4)

                                VStack(spacing: 0) {
                                    ForEach(viewModel.tasks) { task in
                                        TomorrowHabitToggleRow(
                                            task: task,
                                            isSkipped: task.isSkippedTomorrow,
                                            onToggle: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    viewModel.toggleSkipTomorrow(task)
                                                }
                                            }
                                        )
                                        if task.id != viewModel.tasks.last?.id {
                                            Divider()
                                                .background(.white.opacity(0.08))
                                                .padding(.leading, 56)
                                        }
                                    }
                                }
                                .background(.ultraThinMaterial.opacity(0.25))
                                .cornerRadius(18)
                            }
                        }

                        // SECTION 2: One-time extras
                        VStack(alignment: .leading, spacing: 10) {
                            Text("EXTRA STARS")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(2)
                                .padding(.horizontal, 4)

                            if viewModel.tomorrowExtras.isEmpty {
                                Text("One-time tasks that vanish after tomorrow.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundColor(.white.opacity(0.3))
                                    .padding(.horizontal, 4)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.tomorrowExtras) { task in
                                        HStack(spacing: 14) {
                                            Text("✨")
                                                .font(.system(size: 15))
                                                .frame(width: 28)

                                            Text(task.title)
                                                .font(.system(.body, design: .rounded))
                                                .foregroundColor(.white)

                                            Spacer()

                                            Button {
                                                withAnimation(.spring(response: 0.3)) {
                                                    viewModel.removeTomorrowExtra(task)
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundColor(.white.opacity(0.25))
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)

                                        if task.id != viewModel.tomorrowExtras.last?.id {
                                            Divider()
                                                .background(.white.opacity(0.08))
                                                .padding(.leading, 56)
                                        }
                                    }
                                }
                                .background(.ultraThinMaterial.opacity(0.25))
                                .cornerRadius(18)
                            }
                        }

                        // Lock In button — visible when there's an active plan
                        if viewModel.hasTomorrowPlan {
                            Button(action: lockInSky) {
                                Text("LOCK IN THE SKY")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .tracking(2)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [.cyan, .blue.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(16)
                                    .shadow(color: .cyan.opacity(0.5), radius: 12)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
                .animation(.spring(response: 0.4), value: viewModel.hasTomorrowPlan)

                // Add extra field
                VStack(spacing: 0) {
                    Divider().background(.white.opacity(0.08))

                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.cyan)
                            .frame(width: 28, height: 28)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Circle())

                        TextField("Add a one-time star for tomorrow…", text: $newExtraTitle)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                            .tint(.cyan)
                            .focused($isAddFieldFocused)
                            .submitLabel(.done)
                            .onSubmit { commitExtra() }

                        if !newExtraTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button(action: commitExtra) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.cyan)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .animation(.spring(response: 0.3), value: newExtraTitle.isEmpty)
                }
                .background(.ultraThinMaterial.opacity(0.2))
            }

            // Confirmation overlay
            if showConfirmation {
                confirmationOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Confirmation Overlay

    @ViewBuilder
    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("🌙")
                    .font(.system(size: 56))
                Text("Tomorrow's sky is ready.")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                Text(viewModel.selectedVibe == .bestie
                     ? "Rest easy. I'll hold these stars until morning."
                     : "Good. Now sleep — we've got work tomorrow. 🔥")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(36)
            .background(.ultraThinMaterial.opacity(0.85))
            .cornerRadius(28)
            .shadow(color: .cyan.opacity(0.3), radius: 24)
            .padding(40)
        }
    }

    // MARK: - Actions

    private func commitExtra() {
        guard !newExtraTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation(.spring(response: 0.3)) {
            viewModel.addTomorrowExtra(title: newExtraTitle)
        }
        newExtraTitle = ""
        isAddFieldFocused = false
    }

    private func lockInSky() {
        isAddFieldFocused = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.5)) {
                showConfirmation = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        }
    }
}

// MARK: - Habit Toggle Row

private struct TomorrowHabitToggleRow: View {
    let task: HabitTask
    let isSkipped: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isSkipped ? Color.white.opacity(0.06) : Color.cyan.opacity(0.18))
                    .frame(width: 28, height: 28)
                Image(systemName: isSkipped ? "moon.zzz.fill" : "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isSkipped ? .white.opacity(0.2) : .cyan)
            }

            Text(task.title)
                .font(.system(.body, design: .rounded))
                .foregroundColor(isSkipped ? .white.opacity(0.3) : .white)
                .strikethrough(isSkipped, color: .white.opacity(0.2))

            Spacer()

            Button(action: onToggle) {
                Image(systemName: isSkipped ? "circle" : "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(isSkipped ? .white.opacity(0.2) : .cyan)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSkipped)
    }
}
