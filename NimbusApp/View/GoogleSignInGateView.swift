import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices

struct GoogleSignInGateView: View {
    @StateObject private var viewModel = GoogleSignInViewModel()
    @StateObject private var appleViewModel = AppleSignInViewModel()

    @State private var swirlRotation: Double = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.25
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 24

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Rotating angular gradient ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.cyan.opacity(0.5), .purple.opacity(0.3), .cyan.opacity(0), .purple.opacity(0.2), .cyan.opacity(0.5)],
                        center: .center
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 320, height: 320)
                .rotationEffect(.degrees(swirlRotation))
                .blur(radius: 3)

            // Pulsing radial glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.cyan.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .scaleEffect(glowScale)
                .opacity(glowOpacity)

            // Floating particles
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                FloatingSparkle(x: w * 0.15, y: h * 0.20, size: 10, duration: 3.2, delay: 0.0)
                FloatingSparkle(x: w * 0.82, y: h * 0.15, size:  7, duration: 2.8, delay: 0.6)
                FloatingSparkle(x: w * 0.70, y: h * 0.35, size: 12, duration: 3.6, delay: 1.1)
                FloatingSparkle(x: w * 0.10, y: h * 0.50, size:  8, duration: 2.5, delay: 0.3)
                FloatingSparkle(x: w * 0.88, y: h * 0.60, size:  9, duration: 3.0, delay: 0.9)
                FloatingSparkle(x: w * 0.25, y: h * 0.75, size:  6, duration: 2.7, delay: 1.4)
                FloatingSparkle(x: w * 0.60, y: h * 0.78, size: 11, duration: 3.4, delay: 0.5)
            }
            .ignoresSafeArea()

            // Content
            VStack(spacing: 32) {
                Spacer()

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
                    if viewModel.isLoading || appleViewModel.isLoading {
                        ProgressView()
                            .tint(.cyan)
                            .frame(height: 52)
                    } else {
                        // Google button
                        Button {
                            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                  let rootVC = windowScene.windows.first?.rootViewController else { return }
                            Task { await viewModel.signIn(presentingViewController: rootVC) }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 32, height: 32)
                                    Text("G")
                                        .font(.system(size: 17, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                                }
                                Text("Sign in with Google")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.cyan.opacity(0.6), .purple.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .cornerRadius(18)
                        }

                        // Apple button
                        Button {
                            appleViewModel.signIn()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                Text("Sign in with Apple")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .cyan.opacity(0.2)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .cornerRadius(18)
                        }
                    }

                    if let error = viewModel.errorMessage ?? appleViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
            .opacity(contentOpacity)
            .offset(y: contentOffset)
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                swirlRotation = 360
            }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                glowScale = 1.25
                glowOpacity = 0.5
            }
            withAnimation(.easeOut(duration: 0.9).delay(0.1)) {
                contentOpacity = 1
                contentOffset = 0
            }
        }
    }
}

// MARK: - Floating Sparkle Particle

private struct FloatingSparkle: View {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let duration: Double
    let delay: Double

    @State private var bobOffset: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .thin))
            .foregroundStyle(.cyan.opacity(0.55))
            .position(x: x, y: y)
            .offset(y: bobOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).delay(delay)) {
                    opacity = Double.random(in: 0.3...0.7)
                }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) {
                    bobOffset = -12
                }
            }
    }
}
