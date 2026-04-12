import SwiftUI

struct RoleSelectionView: View {
    var onCompletion: (UserRole, String, String) -> Void

    @State private var selectedRole: UserRole? = nil
    @State private var inviteCode: String = ""
    @State private var childEmail: String = ""
    @State private var showInviteField = false

    private var emailIsValid: Bool {
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return childEmail.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Text("☁️")
                        .font(.system(size: 60))
                        .shadow(color: .cyan, radius: 10)

                    Text("Who is Nimbos for?")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Choose how you'd like to use the app.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    RoleCard(
                        icon: "person.fill",
                        title: "Just for me",
                        subtitle: "Personal daily habits",
                        color: .cyan,
                        isSelected: selectedRole == .solo
                    ) {
                        withAnimation { selectedRole = .solo; showInviteField = false }
                    }

                    RoleCard(
                        icon: "person.2.fill",
                        title: "I'm a parent",
                        subtitle: "Manage my children's habits & track progress",
                        color: .purple,
                        isSelected: selectedRole == .parent
                    ) {
                        withAnimation { selectedRole = .parent; showInviteField = false }
                    }

                    RoleCard(
                        icon: "star.fill",
                        title: "I'm joining my family",
                        subtitle: "My parent set up a family for me",
                        color: .orange,
                        isSelected: selectedRole == .child
                    ) {
                        withAnimation { selectedRole = .child; showInviteField = true }
                    }

                    if showInviteField {
                        VStack(spacing: 10) {
                            TextField("Enter family invite code", text: $inviteCode)
                                .font(.system(.body, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                                        )
                                )

                            TextField("Your email address", text: $childEmail)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(emailIsValid ? Color.orange : Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                if let role = selectedRole,
                   role != .child || (inviteCode.count >= 6 && emailIsValid) {
                    Button {
                        onCompletion(role, inviteCode.uppercased(), childEmail.trimmingCharacters(in: .whitespaces))
                    } label: {
                        Text("CONTINUE")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Capsule().fill(roleColor))
                            .shadow(color: roleColor.opacity(0.4), radius: 10)
                    }
                    .padding(.horizontal, 60)
                    .padding(.bottom, 50)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private var roleColor: Color {
        switch selectedRole {
        case .parent: return .purple
        case .child:  return .orange
        default:      return .cyan
        }
    }
}

// MARK: - Role Card

private struct RoleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? color : .white.opacity(0.5))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(isSelected ? color.opacity(0.2) : Color.white.opacity(0.06))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? color : .white.opacity(0.2))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color.opacity(0.08) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? color.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
