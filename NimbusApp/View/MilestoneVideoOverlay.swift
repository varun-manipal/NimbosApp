import SwiftUI
import AVKit

struct MilestoneVideoOverlay: View {
    let onFinished: () -> Void

    @State private var player: AVPlayer? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            guard let url = Bundle.main.url(forResource: "Task_Transition_Video_Generation", withExtension: "mp4") else { return }
            let p = AVPlayer(url: url)
            player = p
            p.play()

            // Dismiss as soon as the video ends
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: p.currentItem,
                queue: .main
            ) { _ in
                onFinished()
            }
        }
        .onDisappear {
            player?.pause()
            NotificationCenter.default.removeObserver(self)
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
    }
}
