import SwiftUI

struct IdentityView: View {
    @State private var name: String = ""
    @State private var pulseScale: CGFloat = 1.0

    var onCompletion: (String) -> Void

    var body: some View {
        ZStack {
            // 1. Reactive Background
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

            // 2. Rainbow sparkle particles
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                RainbowSparkle(x: w * 0.12, y: h * 0.10, size: 10, color: .red,    duration: 3.1, delay: 0.0)
                RainbowSparkle(x: w * 0.80, y: h * 0.08, size:  7, color: .orange,  duration: 2.7, delay: 0.5)
                RainbowSparkle(x: w * 0.55, y: h * 0.18, size: 13, color: .yellow,  duration: 3.5, delay: 1.0)
                RainbowSparkle(x: w * 0.25, y: h * 0.30, size:  8, color: .green,   duration: 2.9, delay: 0.3)
                RainbowSparkle(x: w * 0.88, y: h * 0.35, size: 11, color: .cyan,    duration: 3.3, delay: 0.8)
                RainbowSparkle(x: w * 0.08, y: h * 0.55, size:  9, color: .blue,    duration: 2.6, delay: 1.3)
                RainbowSparkle(x: w * 0.70, y: h * 0.60, size: 12, color: .purple,  duration: 3.7, delay: 0.2)
                RainbowSparkle(x: w * 0.40, y: h * 0.72, size:  7, color: .pink,    duration: 2.8, delay: 0.7)
                RainbowSparkle(x: w * 0.90, y: h * 0.75, size: 10, color: .red,     duration: 3.2, delay: 1.1)
                RainbowSparkle(x: w * 0.18, y: h * 0.85, size:  8, color: .orange,  duration: 3.0, delay: 0.4)
                RainbowSparkle(x: w * 0.62, y: h * 0.88, size: 11, color: .yellow,  duration: 2.5, delay: 0.9)
            }
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // 3. Nimbos Fragment (The "Spark")
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

                // 4. The Question
                VStack(spacing: 12) {
                    Text("I am Nimbos.")
                        .font(.system(.title, design: .rounded))
                        .fontWeight(.bold)

                    Text("What should I call you, Guardian?")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .foregroundColor(.white)

                // 5. Text field — clipped blur background to remove shadow bleed
                TextField("", text: $name, prompt: Text("Your Name or Nickname").foregroundColor(.white.opacity(0.3)))
                    .font(.system(.title2, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.white.opacity(0.1))
                            .overlay(
                                Blur(style: .systemUltraThinMaterialDark)
                                    .clipShape(RoundedRectangle(cornerRadius: 20))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(name.count > 2 ? Color.cyan : Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 40)
                    .submitLabel(.next)

                Spacer()

                // 6. Sync Button
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

// MARK: - Rainbow Sparkle Particle

private struct RainbowSparkle: View {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let color: Color
    let duration: Double
    let delay: Double

    @State private var bobOffset: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.6

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .thin))
            .foregroundStyle(color.opacity(0.8))
            .shadow(color: color.opacity(0.6), radius: 4)
            .position(x: x, y: y)
            .offset(y: bobOffset)
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeOut(duration: 0.7).delay(delay)) {
                    opacity = Double.random(in: 0.5...0.9)
                    scale = 1.0
                }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) {
                    bobOffset = -14
                }
            }
    }
}
