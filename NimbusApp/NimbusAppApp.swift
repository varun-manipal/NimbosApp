//
//  NimbusAppApp.swift
//  NimbusApp
//
//  Created by Varun Gupta on 3/20/26.
//

import SwiftUI
import GoogleSignIn

@main
struct NimbusAppApp: App {
    @AppStorage(OnboardingViewModel.onboardingCompleteKey) private var isOnboardingComplete = false
    @AppStorage("nimbus_googleAuthComplete") private var isGoogleAuthComplete = false
    @AppStorage("nimbus_appleAuthComplete") private var isAppleAuthComplete = false
    @AppStorage(OnboardingViewModel.roleKey) private var userRole = "solo"

    init() {
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: "181444937879-21hnunq53cqk2l2hr3llptjjiarll5qh.apps.googleusercontent.com"
        )
    }
    @StateObject private var habitViewModel = HabitViewModel()
    @StateObject private var dailyRefresh   = DailyRefreshViewModel()
    @StateObject private var notifications  = NotificationViewModel()
    @StateObject private var familyViewModel = FamilyViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if isOnboardingComplete {
                    if userRole == UserRole.parent.rawValue {
                        ParentDashboardView(viewModel: familyViewModel, habitViewModel: habitViewModel,
                                            onSignOut: { familyViewModel.reset() })
                    } else {
                        MainDashboardView(viewModel: habitViewModel,
                                          onSignOut: { familyViewModel.reset() })
                    }
                } else if isGoogleAuthComplete || isAppleAuthComplete {
                    OnboardingFlowView()
                } else {
                    GoogleSignInGateView()
                }
            }
            .animation(.easeInOut(duration: 0.8), value: isOnboardingComplete)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .onChange(of: isOnboardingComplete) { completed in
                if completed {
                    // Onboarding just finished — reload HabitViewModel from the
                    // UserDefaults data that OnboardingViewModel.setPin() persisted.
                    habitViewModel.reload()
                }
            }
            .onChange(of: scenePhase) { phase in
                guard isOnboardingComplete else { return }
                if phase == .active {
                    dailyRefresh.checkForNewDay(habitViewModel: habitViewModel)
                    habitViewModel.reload()
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
