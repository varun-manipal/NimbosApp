//
//  NimbusAppApp.swift
//  NimbusApp
//
//  Created by Varun Gupta on 3/20/26.
//

import SwiftUI

@main
struct NimbusAppApp: App {
    @AppStorage(OnboardingViewModel.onboardingCompleteKey) private var isOnboardingComplete = false
    @State private var habitViewModel = HabitViewModel()
    @State private var dailyRefresh   = DailyRefreshViewModel()
    @State private var notifications  = NotificationViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if isOnboardingComplete {
                    MainDashboardView(viewModel: habitViewModel)
                } else {
                    OnboardingFlowView()
                }
            }
            .animation(.easeInOut(duration: 0.8), value: isOnboardingComplete)
            .onChange(of: isOnboardingComplete) { _, completed in
                if completed {
                    // Onboarding just finished — reload HabitViewModel from the
                    // UserDefaults data that OnboardingViewModel.setVibe() persisted.
                    habitViewModel = HabitViewModel()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard isOnboardingComplete else { return }
                if phase == .active {
                    dailyRefresh.checkForNewDay(habitViewModel: habitViewModel)
                    // Reset the 3-day ghosting timer on every open
                    notifications.scheduleAll(userName: habitViewModel.userName,
                                              vibe: habitViewModel.selectedVibe)
                } else if phase == .background {
                    // Cancel evening nudge if user is already ≥ 50% done
                    if habitViewModel.dailyCompletionPercentage >= 0.5 {
                        notifications.cancelEvening()
                    }
                }
            }
        }
    }
}
