import SwiftUI

struct IdentityView: View {
    @State private var name: String = ""
    @State private var pulseScale: CGFloat = 1.0

    var onCompletion: (String) -> Void

    var body: some View {
        ZStack {
            // 1. Reactive Background Layer
            LinearGradient(
                colors: [
                    name.isEmpty ? .black : .cyan.opacity(0.3),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.5), value: name)

            VStack(spacing: 40) {
                Spacer()

                // 2. Nimbos Fragment (The "Spark")
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.2))
                        .blur(radius: 20)
                        .scaleEffect(pulseScale)

                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundColor(.cyan)
                        .shadow(color: .cyan, radius: 10)
                }
                .frame(height: 150)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        pulseScale = 1.2
                    }
                }

                // 3. The Question
                VStack(spacing: 12) {
                    Text("I am Nimbos.")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)

                    Text("What should I call you, Guardian?")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .foregroundColor(.white)

                // 4. Custom Glassmorphic Input
                TextField("", text: $name, prompt: Text("Your Name or Nickname").foregroundColor(.white.opacity(0.3)))
                    .font(.system(.title2, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.white.opacity(0.1))
                            .background(Blur(style: .systemUltraThinMaterialDark))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(name.count > 2 ? Color.cyan : Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 40)
                    .submitLabel(.next)

                Spacer()

                // 5. Sync Button
                if name.count >= 2 {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        onCompletion(name)
                    }) {
                        HStack {
                            Text("SYNC VIBE")
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(Color.cyan))
                        .shadow(color: .cyan.opacity(0.4), radius: 10)
                    }
                    .padding(.horizontal, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 50)
        }
    }
}
