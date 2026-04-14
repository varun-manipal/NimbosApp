import SwiftUI

struct ParentDashboardView: View {
    @ObservedObject var viewModel: FamilyViewModel
    @ObservedObject var habitViewModel: HabitViewModel
    var onSignOut: (() -> Void)? = nil
    @State private var showInviteSheet = false
    @State private var showProfile = false
    @State private var selectedChild: ChildProgressDTO? = nil

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.familyName.isEmpty ? "My Family" : viewModel.familyName)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                        Text("Parent Dashboard")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                            .tracking(1)
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        Button { showProfile = true } label: {
                            Image(systemName: "person.circle")
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(9)
                                .background(Circle().fill(.ultraThinMaterial.opacity(0.6)))
                        }
                        Button { showInviteSheet = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.badge.plus")
                                Text("Add Child")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.purple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(Color.purple.opacity(0.15))
                                    .overlay(Capsule().stroke(Color.purple.opacity(0.4), lineWidth: 1))
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 24)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(.cyan)
                    Spacer()
                } else if viewModel.children.isEmpty && viewModel.pendingInvites.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48, weight: .thin))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No children yet")
                            .font(.system(.body, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Tap \"Add Child\" to generate an invite code.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await viewModel.loadChildren() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundColor(.cyan)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Active children
                            ForEach(viewModel.children, id: \.userId) { child in
                                ChildCard(child: child)
                                    .onTapGesture { selectedChild = child }
                            }

                            // Pending invites
                            if !viewModel.pendingInvites.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("PENDING INVITES")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.orange.opacity(0.7))
                                        .tracking(1)
                                        .padding(.horizontal, 4)

                                    ForEach(viewModel.pendingInvites, id: \.inviteCode) { invite in
                                        PendingInviteCard(invite: invite) {
                                            Task { await viewModel.deleteInvite(inviteCode: invite.inviteCode) }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                    .refreshable {
                        await viewModel.loadChildren()
                    }
                }
            }
        }
        .task {
            await viewModel.loadFamily()
            await viewModel.loadChildren()
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(viewModel: habitViewModel, onSignOut: onSignOut)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showInviteSheet, onDismiss: {
            Task { await viewModel.loadChildren() }
        }) {
            InviteCodeView(viewModel: viewModel)
        }
        .sheet(item: $selectedChild) { child in
            ChildDetailView(child: child, viewModel: viewModel)
        }
    }
}

// MARK: - Child Card

private struct ChildCard: View {
    let child: ChildProgressDTO

    var body: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: child.dailyCompletionPercentage)
                    .stroke(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text("\(Int(child.dailyCompletionPercentage * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 5) {
                Text(child.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)
                HStack(spacing: 12) {
                    Label("\(child.totalStars) stars", systemImage: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                    Label("\(child.tasks.filter { $0.isCompleted }.count)/\(child.tasks.filter { !$0.isTomorrowOnly }.count) today", systemImage: "checkmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.green.opacity(0.8))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}

// MARK: - Pending Invite Card

private struct PendingInviteCard: View {
    let invite: InviteResponse
    let onDelete: () -> Void

    @State private var showDeleteAlert = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "hourglass")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(invite.email)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("Code: \(invite.inviteCode)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.orange.opacity(0.8))
                    Text("· Waiting to join")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            Button { showDeleteAlert = true } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(.red.opacity(0.7))
                    .padding(8)
                    .background(Circle().fill(Color.red.opacity(0.1)))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.2), lineWidth: 1))
        )
        .alert("Cancel Invite?", isPresented: $showDeleteAlert) {
            Button("Cancel Invite", role: .destructive) { onDelete() }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("The invite code for \(invite.email) will be invalidated.")
        }
    }
}

// Make ChildProgressDTO identifiable for sheet(item:)
extension ChildProgressDTO: Identifiable {
    public var id: UUID { userId }
}
