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

        if role == .parent {
            // Parents skip tasks/vibe — register immediately and go to dashboard
            registerAndComplete()
        } else {
            // Solo/Child — collect tasks and vibe first
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

                // Family setup
                if role == .parent {
                    _ = try? await APIClient.shared.createFamily(name: "\(userName)'s Family")
                } else if role == .child && !inviteCode.isEmpty {
                    _ = try? await APIClient.shared.joinFamily(inviteCode: inviteCode, email: childEmail)
                }

            } catch {
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
