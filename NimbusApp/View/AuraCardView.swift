import SwiftUI

struct AuraCardView: View {
    let totalStarsLit: Int
    let userName: String
    let nimbosStateImage: String

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image(nimbosStateImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Preview of the aura card
                AuraCardContent(
                    totalStarsLit: totalStarsLit,
                    userName: userName,
                    nimbosStateImage: nimbosStateImage,
                    stageTitle: stageTitle
                )
                .cornerRadius(28)
                .shadow(color: .black.opacity(0.4), radius: 30)
                .padding(.horizontal, 32)

                Spacer()

                // Share button
                Button {
                    generateAndShare()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Aura")
                            .fontWeight(.semibold)
                    }
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 40)
                    .background(Color.white)
                    .cornerRadius(30)
                    .shadow(color: .cyan.opacity(0.4), radius: 12)
                }
                .padding(.bottom, 52)
            }
        }
    }

    private var stageTitle: String {
        if totalStarsLit < 12 { return "Mist Child" }
        if totalStarsLit < 35 { return "The Spark" }
        if totalStarsLit < 50 { return "The Float" }
        return "Soft Ignition"
    }

    @MainActor
    private func generateAndShare() {
        let card = AuraCardContent(
            totalStarsLit: totalStarsLit,
            userName: userName,
            nimbosStateImage: nimbosStateImage,
            stageTitle: stageTitle
        )
        .frame(width: 360, height: 480)

        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale

        guard let uiImage = renderer.uiImage else { return }

        let controller = UIActivityViewController(activityItems: [uiImage], applicationActivities: nil)

        // iPad requires a source for the popover anchor
        if let popover = controller.popoverPresentationController {
            let keyWindow = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            popover.sourceView = keyWindow
            popover.sourceRect = CGRect(
                x: keyWindow?.bounds.midX ?? 0,
                y: keyWindow?.bounds.midY ?? 0,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController else { return }

        // Walk to the topmost presented view controller so we don't
        // present on one that's already presenting (e.g. the Aura sheet).
        var top = root
        while let next = top.presentedViewController { top = next }
        top.present(controller, animated: true)
    }
}

// MARK: - Aura Card Content (also used by ImageRenderer)

struct AuraCardContent: View {
    let totalStarsLit: Int
    let userName: String
    let nimbosStateImage: String
    let stageTitle: String

    var body: some View {
        ZStack {
            Image(nimbosStateImage)
                .resizable()
                .scaledToFill()
                .frame(width: 360, height: 480)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "sparkles")
                        .foregroundColor(.cyan)
                        .font(.system(size: 18))
                        .padding(14)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text(stageTitle.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                        .tracking(3)
                    Text("\(totalStarsLit) Star Shards")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    if !userName.isEmpty {
                        Text(userName)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Text(formattedDate)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .frame(width: 360, height: 480)
        }
        .frame(width: 360, height: 480)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: Date())
    }
}

