import SwiftUI

enum VibeType: String {
    case bestie = "Bestie 💖"
    case boss = "Boss 🔥"
}

struct VibeCheckView: View {
    @State private var sliderValue: Double = 0.0 // 0.0 = Bestie, 1.0 = Boss
    @State private var nimbosScale: CGFloat = 1.0

    var onCompletion: (VibeType) -> Void
    
    var body: some View {
        ZStack {
            // 1. Dynamic Background
            // Shifts from soft Pink/Cyan to deep Purple/Indigo
            LinearGradient(
                colors: [
                    Color.pink.opacity(0.2 * (1 - sliderValue)),
                    Color.purple.opacity(0.3 * sliderValue),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut, value: sliderValue)

            VStack(spacing: 40) {
                // 2. Nimbos Expression Area
                VStack(spacing: 20) {
                    Text(sliderValue < 0.5 ? "◕‿◕" : "ಠ_ಠ") // Nimbos changes face
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: sliderValue < 0.5 ? .pink : .purple, radius: 20)
                        .scaleEffect(nimbosScale)
                    
                    Text(sliderValue < 0.5 ? "BESTIE MODE" : "BOSS MODE")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.black)
                        .foregroundColor(.white)
                }
                .frame(height: 200)

                // 3. The Choice Description
                Text(sliderValue < 0.5 ?
                     "I'll be your biggest fan. Soft nudges, lots of sparkles, and zero judgment." :
                     "I'll be your discipline. Real talk, high standards, and no excuses.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .frame(height: 80)

                // 4. Custom Vibe Slider
                VStack(spacing: 15) {
                    HStack {
                        Text("Soft").font(.caption).foregroundColor(.pink)
                        Spacer()
                        Text("Strict").font(.caption).foregroundColor(.purple)
                    }
                    .padding(.horizontal, 50)
                    
                    Slider(value: $sliderValue, in: 0...1)
                        .accentColor(sliderValue < 0.5 ? .pink : .purple)
                        .padding(.horizontal, 40)
                        .onChange(of: sliderValue) { _ in
                            triggerLightHaptic()
                        }
                }

                Spacer()

                // 5. Finalize Button
                Button(action: {
                    let finalVibe: VibeType = sliderValue < 0.5 ? .bestie : .boss
                    finalizeOnboarding(vibe: finalVibe)
                }) {
                    Text("SET MY VIBE")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(Color.white))
                        .shadow(radius: 10)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
    }
    
    private func triggerLightHaptic() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
    }
    
    private func finalizeOnboarding(vibe: VibeType) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onCompletion(vibe)
    }
}
