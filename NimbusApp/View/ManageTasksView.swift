import SwiftUI

struct ManageTasksView: View {
    @ObservedObject var viewModel: HabitViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newTaskTitle = ""
    @FocusState private var isAddFieldFocused: Bool

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

            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Manage Habits")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)

                // Task list
                if viewModel.tasks.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 36))
                            .foregroundColor(.cyan.opacity(0.5))
                        Text("No habits yet.\nAdd one below to get started.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(viewModel.tasks) { task in
                                TaskManageRow(
                                    task: task,
                                    onRename: { newTitle in viewModel.renameTask(task, title: newTitle) },
                                    onDelete: { viewModel.removeTask(task) }
                                )
                                if task.id != viewModel.tasks.last?.id {
                                    Divider()
                                        .background(.white.opacity(0.08))
                                        .padding(.leading, 52)
                                }
                            }
                        }
                        .background(.ultraThinMaterial.opacity(0.25))
                        .cornerRadius(18)
                        .padding(.horizontal, 20)
                    }
                }

                // Add new habit
                VStack(spacing: 0) {
                    Divider().background(.white.opacity(0.08))

                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.cyan)
                            .frame(width: 28, height: 28)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Circle())

                        TextField("Add a new habit…", text: $newTaskTitle)
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white)
                            .tint(.cyan)
                            .focused($isAddFieldFocused)
                            .submitLabel(.done)
                            .onSubmit { commitNewTask() }

                        if !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button(action: commitNewTask) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.cyan)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .animation(.spring(response: 0.3), value: newTaskTitle.isEmpty)
                }
                .background(.ultraThinMaterial.opacity(0.2))
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func commitNewTask() {
        viewModel.addTask(title: newTaskTitle)
        newTaskTitle = ""
    }
}

// MARK: - Individual manage row

private struct TaskManageRow: View {
    let task: HabitTask
    var onRename: (String) -> Void
    var onDelete: () -> Void

    @State private var editedTitle: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.25))

            TextField("", text: $editedTitle)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.white)
                .tint(.cyan)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { commitEdit() }
                .onChange(of: isFocused) { focused in
                    if !focused { commitEdit() }
                }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.6))
                    .padding(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear { editedTitle = task.title }
    }

    private func commitEdit() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            editedTitle = task.title   // revert
        } else {
            onRename(trimmed)
        }
    }
}
