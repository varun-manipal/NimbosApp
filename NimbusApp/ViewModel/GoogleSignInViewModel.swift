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

        // Revoke tokens and clear all cached state so the full OAuth flow always
        // runs, guaranteeing a fresh ID token. disconnect() is a no-op (try?) when
        // there is no current user.
        try? await GIDSignIn.sharedInstance.disconnect()

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Sign in failed. Please try again."
                return
            }

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
                let role = response.user?.role ?? "solo"
                AppDelegate.flushCachedApnsToken(role: role)
                if let email = response.email { UserDefaults.standard.set(email, forKey: "nimbus_email") }
                UserDefaults.standard.set(role, forKey: OnboardingViewModel.roleKey)
                // Triggers NimbusAppApp to show MainDashboardView / ParentDashboardView
                UserDefaults.standard.set(true, forKey: OnboardingViewModel.onboardingCompleteKey)
            }
        } catch let apiError as APIError {
            print("[Auth] Backend error: \(apiError)")
            errorMessage = apiError.localizedDescription
        } catch {
            // Error came from the Google Sign-In SDK (before the network call)
            let ns = error as NSError
            print("[Auth] GIDSignIn error — domain: \(ns.domain), code: \(ns.code), desc: \(ns.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
