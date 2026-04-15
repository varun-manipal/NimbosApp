import SwiftUI
import Combine

enum OnboardingStep {
    case identity
    case roleSelection
    case constellation
    case vibeCheck
}

enum UserRole: String {
    case solo = "solo"
    case parent = "parent"
    case child = "child"
}

class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .identity
    @Published var userName: String = ""
    @Published var selectedHabits: [HabitTask] = []
    @Published var selectedVibe: VibeType = .bestie
    @Published var selectedRole: UserRole = .solo
    @Published var inviteCode: String = ""
    @Published var childEmail: String = ""

    static let onboardingCompleteKey = "nimbus_onboardingComplete"
    static let roleKey = "nimbus_role"

    // MARK: - Navigation

    func goBack() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            switch currentStep {
            case .roleSelection: currentStep = .identity
            case .constellation: currentStep = .roleSelection
            case .vibeCheck:     currentStep = .constellation
            case .identity:      break
            }
        }
    }

    // MARK: - Step setters

    func setName(_ name: String) {
        userName = name
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentStep = .roleSelection
        }
    }

    func setRole(_ role: UserRole, inviteCode: String = "", email: String = "") {
        selectedRole = role
        self.inviteCode = inviteCode
        self.childEmail = email
        UserDefaults.standard.set(role.rawValue, forKey: Self.roleKey)

        if role == .parent || !inviteCode.isEmpty {
            // Parents and invite-joiners (child or co-parent) skip tasks/vibe — register immediately
            registerAndComplete()
        } else {
            // Solo users — collect tasks and vibe first
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                currentStep = .constellation
            }
        }
    }

    func setHabits(_ habitTitles: [String]) {
        selectedHabits = habitTitles.map { HabitTask(title: $0) }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentStep = .vibeCheck
        }
    }

    func setVibe(_ vibe: VibeType) {
        selectedVibe = vibe
        // Solo/Child path completes here after collecting tasks + vibe
        registerAndComplete()
    }

    // MARK: - Registration

    private func registerAndComplete() {
        let role = selectedRole
        let inviteCode = self.inviteCode
        let childEmail = self.childEmail

        let notifications = NotificationViewModel()
        notifications.requestPermission()
        notifications.scheduleAll(userName: userName, vibe: selectedVibe)
        notifications.scheduleEvening(userName: userName, vibe: selectedVibe)

        Task {
            do {
                let googleId   = UserDefaults.standard.string(forKey: "nimbus_pendingGoogleId")
                let googleEmail = UserDefaults.standard.string(forKey: "nimbus_pendingEmail")
                let appleId    = UserDefaults.standard.string(forKey: "nimbus_pendingAppleId")
                let appleEmail = UserDefaults.standard.string(forKey: "nimbus_pendingEmail")

                let response = try await APIClient.shared.register(
                    deviceId: APIClient.deviceId,
                    name: userName,
                    vibe: selectedVibe.serviceValue,
                    pin: nil,
                    tasks: role == .parent ? [] : selectedHabits.map { $0.title },
                    role: role.rawValue,
                    googleId: googleId,
                    appleId: appleId,
                    email: googleEmail ?? appleEmail
                )
                APIClient.shared.saveToken(response.token)

                // Persist email for profile display
                if let email = googleEmail ?? appleEmail {
                    UserDefaults.standard.set(email, forKey: "nimbus_email")
                }

                // Clear pending auth credentials
                for key in ["nimbus_pendingGoogleId", "nimbus_pendingEmail", "nimbus_googleAuthComplete",
                            "nimbus_pendingAppleId", "nimbus_pendingFullName", "nimbus_appleAuthComplete"] {
                    UserDefaults.standard.removeObject(forKey: key)
                }

                // Family setup.
                // createFamily is now idempotent on the server — a 200 or 409 both mean the
                // user's DB role is Parent. We use try? so a transient network failure here
                // does NOT block onboarding; the role was already set to "parent" on the User
                // row by the /users registration call above.
                if role == .parent {
                    _ = try? await APIClient.shared.createFamily(name: "\(userName)'s Family")
                    // Belt-and-suspenders: ensure the local role key is "parent" so the router
                    // shows ParentDashboardView regardless of any async race on applyUserDTO.
                    UserDefaults.standard.set(UserRole.parent.rawValue, forKey: Self.roleKey)
                } else if role == .child && !inviteCode.isEmpty {
                    _ = try? await APIClient.shared.joinFamily(inviteCode: inviteCode, email: childEmail)
                    // Ask the server for the authoritative role — the invite might be for a
                    // co-parent, in which case the server sets User.Role = Parent. Update
                    // UserDefaults now so routing goes to the right dashboard immediately.
                    if let me = try? await APIClient.shared.getMe(), let serverRole = me.role {
                        await MainActor.run {
                            UserDefaults.standard.set(serverRole.lowercased(), forKey: Self.roleKey)
                        }
                    }
                }

            } catch {
                // Registration itself failed — persist local-only state so the user can still
                // use the app offline, and keep whatever role was written by setRole() so
                // routing is consistent with the user's stated intent.
                let vm = buildHabitViewModel()
                vm.save()
            }

            await MainActor.run {
                UserDefaults.standard.set(true, forKey: Self.onboardingCompleteKey)
            }
        }
    }

    func buildHabitViewModel() -> HabitViewModel {
        let vm = HabitViewModel()
        vm.tasks        = selectedHabits
        vm.userName     = userName
        vm.selectedVibe = selectedVibe
        return vm
    }
}
