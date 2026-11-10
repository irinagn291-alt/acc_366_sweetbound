import AVFAudio

@MainActor
final class TrailAudio {
    enum Cue: String, CaseIterable {
        case jump
        case splash
        case bump
    }

    private var players: [Cue: AVAudioPlayer] = [:]

    init() {
        // Ambient playback mixes with other audio and follows the Ring/Silent switch.
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
        } catch {
            return
        }

        for cue in Cue.allCases {
            guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[cue] = player
        }
    }

    func play(_ cue: Cue) {
        guard let player = players[cue] else { return }
        player.currentTime = 0
        player.play()
    }
}
