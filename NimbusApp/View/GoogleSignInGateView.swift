import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct GoogleSignInGateView: View {
    @StateObject private var viewModel = GoogleSignInViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                Image(systemName: "sparkles")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(.cyan)

                VStack(spacing: 12) {
                    Text("Nimbos")
                        .font(.system(size: 36, weight: .thin, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Your Nimbos lives in the cloud.\nSign in to find it.")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.cyan)
                    } else {
                        GoogleSignInButton(scheme: .dark, style: .wide, state: .normal) {
                            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                  let rootVC = windowScene.windows.first?.rootViewController else { return }
                            Task { await viewModel.signIn(presentingViewController: rootVC) }
                        }
                        .frame(height: 50)
                        .cornerRadius(12)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }
}
