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
                // Cache first name to pre-populate the identity screen
                let givenName = result.user.profile?.givenName ?? result.user.profile?.name
                UserDefaults.standard.set(givenName, forKey: "nimbus_pendingGivenName")
                // Triggers NimbusAppApp to show OnboardingFlowView
                UserDefaults.standard.set(true, forKey: "nimbus_googleAuthComplete")
            } else {
                // Returning user — save token and jump straight to dashboard
                guard let token = response.token else {
                    errorMessage = "Sign in failed. Please try again."
                    return
                }
                APIClient.shared.saveToken(token)
                if let email = response.email { UserDefaults.standard.set(email, forKey: "nimbus_email") }
                // Always write the role before setting onboardingComplete so the routing
                // check in NimbusAppApp reads the correct value on the same render pass.
                // Fall back to "solo" only if the server omits the field (should never happen).
                let role = response.user?.role ?? "solo"
                UserDefaults.standard.set(role, forKey: OnboardingViewModel.roleKey)
                // Triggers NimbusAppApp to show MainDashboardView / ParentDashboardView
                UserDefaults.standard.set(true, forKey: OnboardingViewModel.onboardingCompleteKey)
            }
        } catch {
            print("Google Sign-In error: \(error)")
            errorMessage = error.localizedDescription
        }
    }
}
