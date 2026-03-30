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
        // Persist PIN before building the habit VM so HabitViewModel.load() picks it up.
        UserDefaults.standard.set(pin, forKey: "nimbus_pin")

        // Build and persist the HabitViewModel before signalling completion,
        // so NimbusAppApp can load it immediately via HabitViewModel.init().
        let vm = buildHabitViewModel()
        vm.save()

        // Request notification permission and schedule standing notifications.
        let notifications = NotificationViewModel()
        notifications.requestPermission()
        notifications.scheduleAll(userName: userName, vibe: selectedVibe)
        notifications.scheduleEvening(userName: userName, vibe: selectedVibe)

        // Flip the flag — @AppStorage in NimbusAppApp reacts and swaps the root view.
        UserDefaults.standard.set(true, forKey: Self.onboardingCompleteKey)
    }

    func buildHabitViewModel() -> HabitViewModel {
        let vm = HabitViewModel()
        vm.tasks        = selectedHabits
        vm.userName     = userName
        vm.selectedVibe = selectedVibe
        return vm
    }
}
