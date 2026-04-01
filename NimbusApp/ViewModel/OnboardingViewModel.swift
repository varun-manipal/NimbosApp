import SwiftUI
import Combine

enum OnboardingStep {
    case identity
    case constellation
    case vibeCheck
    case pinSetup
}

class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .identity
    @Published var userName: String = ""
    @Published var selectedHabits: [HabitTask] = []
    @Published var selectedVibe: VibeType = .bestie

    static let onboardingCompleteKey = "nimbus_onboardingComplete"

    func setName(_ name: String) {
        userName = name
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentStep = .constellation
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
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            currentStep = .pinSetup
        }
    }

    func setPin(_ pin: String) {
        // Persist PIN locally so HabitViewModel.load() picks it up immediately.
        UserDefaults.standard.set(pin, forKey: "nimbus_pin")

        // Schedule notifications regardless of service availability.
        let notifications = NotificationViewModel()
        notifications.requestPermission()
        notifications.scheduleAll(userName: userName, vibe: selectedVibe)
        notifications.scheduleEvening(userName: userName, vibe: selectedVibe)

        Task {
            do {
                // Pick up Google credentials if the user came through Google Sign-In
                let googleId = UserDefaults.standard.string(forKey: "nimbus_pendingGoogleId")
                let googleEmail = UserDefaults.standard.string(forKey: "nimbus_pendingEmail")

                // Register with the service — this creates the user and all tasks.
                let response = try await APIClient.shared.register(
                    deviceId: APIClient.deviceId,
                    name: userName,
                    vibe: selectedVibe.serviceValue,
                    pin: pin.isEmpty ? nil : pin,
                    tasks: selectedHabits.map { $0.title },
                    googleId: googleId,
                    email: googleEmail
                )
                APIClient.shared.saveToken(response.token)

                // Clear pending Google credentials after successful registration
                if googleId != nil {
                    UserDefaults.standard.removeObject(forKey: "nimbus_pendingGoogleId")
                    UserDefaults.standard.removeObject(forKey: "nimbus_pendingEmail")
                    UserDefaults.standard.removeObject(forKey: "nimbus_googleAuthComplete")
                }
            } catch {
                // Service unavailable — fall back to local persistence so the
                // app still works. State will sync the next time GET /users/me succeeds.
                let vm = buildHabitViewModel()
                vm.save()
            }

            await MainActor.run {
                // Flip the flag — @AppStorage in NimbusAppApp reacts and swaps the root view.
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
