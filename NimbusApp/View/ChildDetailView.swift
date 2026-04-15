import SwiftUI

struct ChildDetailView: View {
    let child: ChildProgressDTO
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newTaskTitle = ""
    @State private var editingTask: TaskDTO? = nil
    @State private var editTitle = ""
    @State private var showAwardsSetup = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress summary
                    HStack(spacing: 24) {
                        StatBadge(value: "\(child.totalStars)", label: "Total Stars", color: .cyan)
                        StatBadge(value: "\(child.dailyStars)", label: "Today's Stars", color: .purple)
                        StatBadge(value: "\(Int(child.dailyCompletionPercentage * 100))%", label: "Completion", color: .green)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.04))

                    // Awards summary
                    let claimedOrPending = viewModel.selectedChildAwards.filter { $0.claimedAwardText != nil || $0.hasAwards }
                    if !claimedOrPending.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(claimedOrPending, id: \.milestoneShards) { award in
                                    if let claimed = award.claimedAwardText {
                                        AwardStatusChip(shards: award.milestoneShards, text: claimed, state: .claimed)
                                    } else if award.hasAwards {
                                        AwardStatusChip(shards: award.milestoneShards, text: "Awaiting choice", state: .pending)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        }
                        .background(Color.white.opacity(0.03))
                    }

                    // Task list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(currentTasks, id: \.id) { task in
                                TaskManagementRow(
                                    task: task,
                                    onDelete: {
                                        Task { await viewModel.removeTask(childId: child.userId, taskId: task.id) }
                                    },
                                    onRename: {
                                        editingTask = task
                                        editTitle = task.title
                                    }
                                )
                                Divider().background(Color.white.opacity(0.06)).padding(.leading, 16)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .refreshable {
                        await viewModel.loadChild(child.userId)
                    }

                    // Add task field
                    HStack(spacing: 12) {
                        TextField("Add a task for \(child.name)...", text: $newTaskTitle)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.white.opacity(0.08))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                            )
                            .submitLabel(.done)
                            .onSubmit { addTask() }

                        Button(action: addTask) {
                            Image(systemName: "plus.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.05, green: 0.05, blue: 0.1))
                }
            }
            .navigationTitle(child.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAwardsSetup = true
                    } label: {
                        Label("Awards", systemImage: "gift.fill")
                            .foregroundColor(.yellow)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.purple)
                }
            }
            .task { await viewModel.loadChildAwards(child.userId) }
            .sheet(isPresented: $showAwardsSetup) {
                MilestoneAwardsSetupView(child: child)
            }
            .alert("Rename Task", isPresented: Binding(
                get: { editingTask != nil },
                set: { if !$0 { editingTask = nil } }
            )) {
                TextField("Task title", text: $editTitle)
                Button("Save") {
                    if let task = editingTask {
                        Task { await viewModel.renameTask(childId: child.userId, taskId: task.id, title: editTitle) }
                    }
                    editingTask = nil
                }
                Button("Cancel", role: .cancel) { editingTask = nil }
            }
        }
    }

    private var currentTasks: [TaskDTO] {
        // Show most up-to-date version from viewModel if available
        let updated = viewModel.children.first(where: { $0.userId == child.userId })
        return (updated ?? child).tasks.filter { !$0.isTomorrowOnly }
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        newTaskTitle = ""
        Task { await viewModel.addTask(to: child.userId, title: title) }
    }
}

// MARK: - Supporting views

private struct StatBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AwardStatusChip: View {
    enum State { case claimed, pending }
    let shards: Int
    let text: String
    let state: State

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(shards) shards")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            Text(state == .claimed ? "✓ \(text)" : "⏳ \(text)")
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(state == .claimed ? .cyan : .white.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(state == .claimed ? 0.08 : 0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
        )
    }
}

private struct TaskManagementRow: View {
    let task: TaskDTO
    let onDelete: () -> Void
    let onRename: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundColor(task.isCompleted ? .cyan : .white.opacity(0.25))

            Text(task.title)
                .font(.system(.body, design: .rounded))
                .foregroundColor(task.isCompleted ? .white.opacity(0.5) : .white)
                .strikethrough(task.isCompleted, color: .white.opacity(0.3))

            Spacer()

            Button(action: onRename) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.trailing, 4)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.6))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
