//
//  SplashScreenView.swift
//  ShopperPlus
//
//  Created by Shaker Gilbert on 8/1/25.
//

import SwiftUI
import AVFoundation

struct SplashScreenView: View {
    @State private var circleScale: CGFloat = 0.5
    @State private var circleOpacity: Double = 0.0
    @State private var soundManager = SoundManager()

    let onSplashComplete: () -> Void

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.blue.opacity(0.8), .purple.opacity(0.6), .pink.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Pulsing yellow circle behind logo
                Circle()
                    .fill(Color.yellow.opacity(0.6))
                    .frame(width: 200, height: 200)
                    .scaleEffect(circleScale)
                    .opacity(circleOpacity)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: circleScale)

                // App Logo (centered, large and static)
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            }
        }
        .onAppear {
            playAnimation()
        }
    }

    private func playAnimation() {
        // Start the pulsing circle animation
        circleOpacity = 0.8
        circleScale = 1.2

        // Play sound after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            soundManager.playSound()
        }

        // Start fading out audio and circle at 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            soundManager.fadeOutAudio(duration: 1.0)

            // Fade out the circle
            withAnimation(.easeOut(duration: 1.0)) {
                circleOpacity = 0.0
            }
        }

        // Complete splash after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            onSplashComplete()
        }
    }
}

class SoundManager: ObservableObject {
    private var audioPlayer: AVAudioPlayer?

    init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    func playSound() {
        // Check if sound is enabled in settings
        let soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        guard soundEnabled else { return }

        guard let soundURL = Bundle.main.url(forResource: "intro", withExtension: "m4a") else {
            print("Could not find intro.m4a file")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.volume = 1.0
            audioPlayer?.play()
        } catch {
            print("Failed to play sound: \(error)")
        }
    }

    func fadeOutAudio(duration: TimeInterval) {
        guard let player = audioPlayer, player.isPlaying else { return }

        let fadeSteps = 20
        let stepDuration = duration / Double(fadeSteps)
        let volumeDecrement = player.volume / Float(fadeSteps)

        for i in 1...fadeSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                player.volume = max(0, player.volume - volumeDecrement)
                if i == fadeSteps {
                    player.stop()
                }
            }
        }
    }
}

#Preview {
    SplashScreenView(onSplashComplete: {})
}
