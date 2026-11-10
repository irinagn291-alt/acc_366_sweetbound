struct PracticeTrail {
    enum Bank: Int { case start = 0, roadside = 1, riverside = 3 }
    enum Event: Equatable { case retry(TrailDeath), completed }

    private var bank = Bank.start
    private var row = 0
    private var mistake: TrailDeath?
    private(set) var isComplete = false

    static func makeGame() -> TrailGame { TrailGame(practiceBank: .start) }

    var stepNumber: Int {
        switch bank {
        case .start: 1
        case .roadside: 2
        case .riverside: 3
        }
    }

    var title: String {
        if isComplete { return "You made it across!" }
        switch bank {
        case .start: return "Your first hop"
        case .roadside: return "Across the road"
        case .riverside: return "Ride the log"
        }
    }

    var instruction: String {
        if isComplete { return "Now try a crossing on your own." }
        switch mistake {
        case .traffic: return "A car caught you. Let it pass, then hop across."
        case .water: return "You missed the log. Wait for the next one to drift closer."
        case .sweptAway: return "The current carried the log away. Hop onto the bank sooner next time."
        case nil: break
        }
        switch row {
        case 0: return "Tap the field or press ↑ to hop forward."
        case 1: return "Wait for a gap between cars and cross the road in two hops."
        case 2: return "One more hop forward takes you to safe grass."
        case 3: return "Wait for a log to line up with you, then hop on."
        default: return "The log carries you along. Hop forward onto the bank!"
        }
    }

    // Observe the same post-physics state used by the renderer and scoring.
    mutating func observe(_ game: inout TrailGame) -> Event? {
        guard !isComplete else { return nil }
        if let death = game.death {
            game = TrailGame(practiceBank: bank)
            row = bank.rawValue
            mistake = death
            return .retry(death)
        }
        if game.score >= 5 {
            isComplete = true
            return .completed
        }
        if game.score >= Bank.riverside.rawValue {
            bank = .riverside
        } else if game.score >= Bank.roadside.rawValue {
            bank = .roadside
        }
        let currentRow = Int(game.playerY.rounded())
        if currentRow != row {
            row = currentRow
            mistake = nil
        }
        return nil
    }
}
