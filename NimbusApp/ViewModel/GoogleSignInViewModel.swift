import SwiftUI
import Combine
import GoogleSignIn

@MainActor
class GoogleSignInViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func signIn(presentingViewController: UIViewController) async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Sign in failed. Please try again."
                return
            }

            print("Google idToken: \(idToken)")
            let response = try await APIClient.shared.googleAuth(idToken: idToken)

            if response.isNewUser {
                // Cache Google credentials for use at end of onboarding
                UserDefaults.standard.set(response.googleId, forKey: "nimbus_pendingGoogleId")
                UserDefaults.standard.set(response.email, forKey: "nimbus_pendingEmail")
                // Triggers NimbusAppApp to show OnboardingFlowView
                UserDefaults.standard.set(true, forKey: "nimbus_googleAuthComplete")
            } else {
                // Returning user — save token and jump straight to dashboard
                APIClient.shared.saveToken(response.token!)
                // Triggers NimbusAppApp to show MainDashboardView
                UserDefaults.standard.set(true, forKey: OnboardingViewModel.onboardingCompleteKey)
            }
        } catch {
            print("Google Sign-In error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
}
