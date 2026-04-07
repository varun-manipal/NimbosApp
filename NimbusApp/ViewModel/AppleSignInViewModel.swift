import SwiftUI
import Combine
import AuthenticationServices

@MainActor
class AppleSignInViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func signIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }

        let userIdentifier = credential.user
        let email = credential.email
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }.joined(separator: " ")
            .nilIfEmpty

        Task {
            isLoading = true
            defer { isLoading = false }
            errorMessage = nil

            do {
                let response = try await APIClient.shared.appleAuth(
                    userIdentifier: userIdentifier,
                    email: email,
                    fullName: fullName
                )

                if response.isNewUser {
                    UserDefaults.standard.set(response.appleId, forKey: "nimbus_pendingAppleId")
                    UserDefaults.standard.set(response.email, forKey: "nimbus_pendingEmail")
                    UserDefaults.standard.set(response.fullName, forKey: "nimbus_pendingFullName")
                    UserDefaults.standard.set(true, forKey: "nimbus_appleAuthComplete")
                } else {
                    APIClient.shared.saveToken(response.token!)
                    UserDefaults.standard.set(true, forKey: OnboardingViewModel.onboardingCompleteKey)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithError error: Error) {
        // User cancelled — no error shown
        guard (error as? ASAuthorizationError)?.code != .canceled else { return }
        errorMessage = error.localizedDescription
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
