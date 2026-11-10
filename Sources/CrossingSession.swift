import SwiftUI
import QuartzCore
import UIKit

enum TrailScreen { case reserve, crossing, paused, result }
enum TrailMode { case classic, daily, practice }

@MainActor
final class CrossingSession: NSObject, ObservableObject {
    @Published private(set) var game = TrailGame(seed: 719)
    @Published private(set) var screen = TrailScreen.reserve
    @Published private(set) var mode = TrailMode.classic
    @Published private(set) var survey: WetlandSurvey?
    @Published private(set) var practice = PracticeTrail()
    @Published private(set) var today = TrailDay()
    @Published private(set) var journal: TrailJournal
    @Published private(set) var best: Int
    @Published private(set) var sound: Bool
    private let defaults: UserDefaults
    #if DEBUG && targetEnvironment(simulator)
    private let captureMode: Bool
    #endif
    private let audio = TrailAudio()
    private var displayLink: CADisplayLink?
    private var previousFrame: CFTimeInterval?
    private var active = false
    private var covered = false
    private var runID = UUID()
    private(set) var recordAtStart = 0

    #if DEBUG && targetEnvironment(simulator)
    init(captureRoute: CaptureRoute? = nil) {
        captureMode = captureRoute != nil
        let store: UserDefaults
        if captureRoute != nil {
            let suite = "games.mossbound.crossing.screenshot-demo"
            let demoDefaults = UserDefaults(suiteName: suite)!
            demoDefaults.removePersistentDomain(forName: suite)
            store = demoDefaults
        } else {
            store = .standard
        }
        defaults = store
        journal = TrailJournal(defaults: store)
        best = store.integer(forKey: "longestCrossing")
        sound = !store.bool(forKey: "quietMarsh")
        super.init()
        if let captureRoute { prepareCapture(captureRoute) }
    }
    #else
    override init() {
        let store = UserDefaults.standard
        defaults = store
        journal = TrailJournal(defaults: store)
        best = store.integer(forKey: "longestCrossing")
        sound = !store.bool(forKey: "quietMarsh")
        super.init()
    }
    #endif

    func setActive(_ active: Bool) {
        #if DEBUG && targetEnvironment(simulator)
        if captureMode { return }
        #endif
        self.active = active
        if active { refreshDay() }
        if !active && screen == .crossing { screen = .paused }
        syncClock()
    }

    func setCovered(_ covered: Bool) {
        self.covered = covered
        syncClock()
    }

    func refreshDay() {
        let current = TrailDay()
        if current != today { today = current }
    }

    func start(_ mode: TrailMode = .classic) {
        refreshDay()
        runID = UUID()
        self.mode = mode
        survey = nil
        switch mode {
        case .classic:
            game = TrailGame(seed: .random(in: .min ... .max))
        case .daily:
            game = TrailGame(seed: today.seed)
            survey = WetlandSurvey(day: today)
        case .practice:
            practice = PracticeTrail()
            game = PracticeTrail.makeGame()
        }
        recordAtStart = best
        screen = .crossing
        syncClock()
    }

    func pause() {
        guard screen == .crossing else { return }
        screen = .paused
        syncClock()
    }

    func resume() {
        guard screen == .paused else { return }
        screen = .crossing
        syncClock()
    }

    func returnToReserve() {
        refreshDay()
        survey = nil
        game = TrailGame(seed: .random(in: .min ... .max))
        screen = .reserve
        syncClock()
    }

    func toggleSound() {
        sound.toggle()
        defaults.set(!sound, forKey: "quietMarsh")
        if sound { audio.play(.jump) }
    }

    func hop(_ direction: TrailDirection) {
        guard screen == .crossing, game.move(direction) else { return }
        if sound { audio.play(.jump) }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func syncClock() {
        previousFrame = nil
        #if DEBUG && targetEnvironment(simulator)
        if captureMode { return }
        #endif
        guard active, !covered, screen == .crossing || screen == .reserve else {
            displayLink?.invalidate()
            displayLink = nil
            return
        }
        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    @objc private func frame(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = previousFrame.map { now - $0 } ?? 0
        previousFrame = now
        advance(dt)
    }

    private func advance(_ dt: Double) {
        guard dt > 0 else { return }
        var landings: [(Int, Int)] = []
        game.update(dt) { landings.append(($0, $1)) }
        guard screen == .crossing else { return }
        if mode == .practice {
            switch practice.observe(&game) {
            case .completed: finish()
            case .retry(let death): playCollision(death)
            case nil: break
            }
            return
        }
        if game.score > best {
            best = game.score
            defaults.set(best, forKey: "longestCrossing")
        }
        for (column, row) in landings where mode == .daily {
            survey?.observe(column: column, row: row, lane: game.lane(at: row))
            if let count = survey?.count, count > journal.discoveredFindCount {
                journal.discoverFinds(upTo: count)
            }
        }
        if survey?.complete == true || game.death != nil {
            if let death = game.death, survey?.complete != true { playCollision(death) }
            journal.record(runID: runID, score: game.score, day: survey?.day, surveyCompleted: survey?.complete == true)
            finish()
        }
    }

    private func finish() {
        screen = .result
        syncClock()
    }

    #if DEBUG && targetEnvironment(simulator)
    private func prepareCapture(_ route: CaptureRoute) {
        switch route {
        case .reserve, .fieldGuide:
            break
        case .dailyExpedition:
            start(.daily)
            _ = game.move(.forward)
            advance(0.2)
        case .practice:
            start(.practice)
            _ = game.move(.forward)
            advance(0.2)
        case .journal:
            prepareTrafficResult()
            start(.daily)
            _ = game.move(.forward)
            advance(0.2)
            returnToReserve()
        case .crossingResult:
            prepareTrafficResult()
        }
    }

    private func prepareTrafficResult() {
        start(.classic)
        game = TrailGame(seed: 719)
        _ = game.move(.forward)
        advance(0.2)
        _ = game.move(.forward)
        advance(0.2)
        // The first road always has cars; advance the real physics until one hits.
        for _ in 0..<100 where screen == .crossing { advance(0.1) }
    }
    #endif

    private func playCollision(_ death: TrailDeath) {
        #if DEBUG && targetEnvironment(simulator)
        if captureMode { return }
        #endif
        if sound { audio.play(death == .traffic ? .bump : .splash) }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
