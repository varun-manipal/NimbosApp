import SwiftUI
import GoogleSignIn

struct ProfileView: View {
    @ObservedObject var viewModel: HabitViewModel
    @Environment(\.dismiss) private var dismiss

    @AppStorage("nimbus_email") private var email: String = ""
    @AppStorage(OnboardingViewModel.onboardingCompleteKey) private var isOnboardingComplete = false
    @AppStorage("nimbus_googleAuthComplete") private var isGoogleAuthComplete = false
    @AppStorage(OnboardingViewModel.roleKey) private var userRole = "solo"

    @State private var editedName: String = ""
    @State private var editedVibe: VibeType = .bestie
    @State private var isSaving = false
    @State private var showSignOutAlert = false
    @State private var saveConfirmed = false

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {

                    // Avatar
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 72, weight: .thin))
                            .foregroundStyle(
                                LinearGradient(colors: [.cyan, .purple], startPoint: .top, endPoint: .bottom)
                            )

                        Text(viewModel.userName.isEmpty ? "Nimbos User" : viewModel.userName)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 24)

                    // Fields
                    VStack(spacing: 0) {
                        // Email — read only
                        ProfileRow(label: "Email") {
                            Text(email.isEmpty ? "Not available" : email)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        Divider().background(Color.white.opacity(0.08))

                        // Name — editable
                        ProfileRow(label: "Name") {
                            TextField("Your name", text: $editedName)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                        }

                        Divider().background(Color.white.opacity(0.08))

                        // Vibe — picker
                        ProfileRow(label: "Vibe") {
                            Picker("Vibe", selection: $editedVibe) {
                                Text("Bestie").tag(VibeType.bestie)
                                Text("Boss").tag(VibeType.boss)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal, 20)

                    // Save button
                    Button {
                        Task { await save() }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(.black)
                            } else if saveConfirmed {
                                Label("Saved", systemImage: "checkmark")
                            } else {
                                Text("Save Changes")
                            }
                        }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(
                                saveConfirmed
                                ? AnyShapeStyle(Color.green)
                                : AnyShapeStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                            )
                        )
                    }
                    .disabled(isSaving)
                    .animation(.spring(response: 0.3), value: saveConfirmed)
                    .padding(.horizontal, 20)

                    // Sign out
                    Button {
                        showSignOutAlert = true
                    } label: {
                        Text("Sign Out")
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundColor(.red.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.08))
                                    .overlay(Capsule().stroke(Color.red.opacity(0.25), lineWidth: 1))
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            editedName = viewModel.userName
            editedVibe = viewModel.selectedVibe
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Sign Out", role: .destructive) { signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign in again to access your Nimbos.")
        }
    }

    // MARK: - Actions

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        try? await APIClient.shared.updateMe(name: editedName, vibe: editedVibe.serviceValue)
        viewModel.userName = editedName
        viewModel.selectedVibe = editedVibe
        viewModel.save()
        withAnimation { saveConfirmed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { saveConfirmed = false }
        }
    }

    private func signOut() {
        GIDSignIn.sharedInstance.signOut()
        let keys = [
            "nimbus_token", "nimbus_onboardingComplete",
            "nimbus_googleAuthComplete", "nimbus_role",
            "nimbus_email", "nimbus_userName", "nimbus_selectedVibe",
            "nimbus_tasks", "nimbus_shield", "nimbus_pin"
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}

// MARK: - Profile Row

private struct ProfileRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
