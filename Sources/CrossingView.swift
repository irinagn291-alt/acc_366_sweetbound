import SwiftUI

#if DEBUG && targetEnvironment(simulator)
enum CaptureRoute: String {
    case reserve, dailyExpedition = "daily-expedition", fieldGuide = "field-guide"
    case practice, journal, crossingResult = "crossing-result"

    static var requested: CaptureRoute? {
        let info = ProcessInfo.processInfo
        let args = info.arguments
        if let index = args.firstIndex(of: "-ReviewScreen"), index + 1 < args.count {
            return CaptureRoute(rawValue: args[index + 1])
        }
        let environment = info.environment
        let enabled = args.contains("-AppStoreScreenshots") ||
            ["1", "true", "yes"].contains(environment["APPSTORE_SCREENSHOTS"]?.lowercased() ?? "")
        guard enabled else { return nil }
        let value: String?
        if let index = args.firstIndex(of: "-AppStoreScreenshotScreen"), index + 1 < args.count {
            value = args[index + 1]
        } else {
            value = environment["APPSTORE_SCREENSHOT_SCREEN"]
        }
        let routes: [CaptureRoute] = [.reserve, .dailyExpedition, .fieldGuide, .practice, .journal, .crossingResult]
        guard let number = Int(value ?? "0"), routes.indices.contains(number) else { return nil }
        return routes[number]
    }
}
#endif

private enum ReserveSheet: String, Identifiable {
    case guide, journal, about
    var id: Self { self }
}

struct CrossingView: View {
    @State private var sheet: ReserveSheet?
    @StateObject private var session: CrossingSession

    init() {
        #if DEBUG && targetEnvironment(simulator)
        let route = CaptureRoute.requested
        let session = CrossingSession(captureRoute: route)
        _session = StateObject(wrappedValue: session)
        switch route {
        case .fieldGuide: _sheet = State(initialValue: .guide)
        case .journal: _sheet = State(initialValue: .journal)
        default: _sheet = State(initialValue: nil)
        }
        #else
        _session = StateObject(wrappedValue: CrossingSession())
        #endif
    }
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ZStack {
            GeometryReader { geo in
                TrailBoard(game: session.game, survey: session.survey)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)

            if session.screen == .reserve {
                reserve
            } else {
                ZStack {
                    if session.screen == .crossing {
                        Rectangle().fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(boardGesture)
                            .accessibilityHidden(true)
                    } else {
                        Field.ink.opacity(0.36).ignoresSafeArea()
                    }
                    VStack(spacing: 0) {
                        playHUD
                        Spacer(minLength: 8)
                        if session.screen == .crossing {
                            if session.mode != .classic { fieldPrompt }
                            directionPad
                        } else {
                            resultPanel
                        }
                    }
                }
            }
        }
        .sheet(item: $sheet) { item in
            if item == .about {
                GameAbout()
            } else {
                FieldNotebook(initialTab: item == .guide ? .guide : .journal,
                              journal: session.journal, best: session.best) {
                    sheet = nil
                    session.start(.practice)
                }
            }
        }
        .transaction { transaction in
            #if DEBUG && targetEnvironment(simulator)
            if CaptureRoute.requested != nil {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
            #endif
        }
        .onChange(of: sheet) { _, value in session.setCovered(value != nil) }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in session.refreshDay() }
        .onAppear { session.setActive(phase == .active) }
        .onChange(of: phase) { _, value in session.setActive(value == .active) }
        .onDisappear { session.setActive(false) }
    }

    private var boardGesture: some Gesture {
        DragGesture(minimumDistance: 0).onEnded { event in
            let dx = event.translation.width
            let dy = event.translation.height
            if max(abs(dx), abs(dy)) < 16 {
                session.hop(.forward)
            } else if abs(dx) > abs(dy) {
                session.hop(dx > 0 ? .right : .left)
            } else {
                session.hop(dy > 0 ? .back : .forward)
            }
        }
    }

    private var reserve: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image("FrogCrest").resizable().scaledToFit().frame(width: 30, height: 26)
                    FieldLabel("WETLAND RESERVE", size: 10)
                    Spacer()
                    Button { sheet = .about } label: {
                        Image(systemName: "info.circle")
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("About and privacy")
                    .accessibilityIdentifier("aboutGame")
                    soundButton
                }
                MossWordmark()
                    .frame(maxWidth: 450, alignment: .leading)
                HStack(spacing: 10) {
                    Rectangle().fill(Field.ink).frame(width: 20, height: 2)
                    FieldLabel("FIELD ARCADE", size: 10)
                    Spacer()
                    FieldLabel("SERIES 01", size: 10)
                }
            }
            .foregroundStyle(Field.ink)
            .padding(.horizontal, 24).padding(.bottom, 16)
            .frame(maxWidth: 580)
            .frame(maxWidth: .infinity)
            .background(Field.paper.ignoresSafeArea(edges: .top))
            Rectangle().fill(Field.ink).frame(height: 3)
            Spacer(minLength: 15)
            footer {
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered").foregroundStyle(Field.lime)
                        FieldLabel("PERSONAL BEST")
                    }
                    Spacer()
                    Text(distance(session.best))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                }
                TrailButton(title: "Start crossing") { session.start() }
                    .accessibilityIdentifier("startCrossing")
                Button { session.start(.daily) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "binoculars.fill").foregroundStyle(Field.amber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily expedition").font(.system(.headline, design: .rounded, weight: .bold))
                            Text(dailyCaption)
                                .font(.system(.caption, design: .rounded)).foregroundStyle(Field.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .frame(minHeight: 47)
                    .background(Field.panel, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain).accessibilityIdentifier("dailyCrossing")
                HStack {
                    notebookButton("How to play", "questionmark.circle", .guide)
                    Rectangle().fill(Field.muted.opacity(0.4)).frame(width: 1, height: 16)
                    notebookButton("Journal", "book.closed", .journal)
                }
            }
        }
    }

    private var dailyCaption: String {
        if session.journal.surveyCompleted(for: session.today) { return "All three observations recorded" }
        if let best = session.journal.dailyBest(for: session.today) { return "Today's best — " + distance(best) + " · Goal — 3 signs" }
        return "One daily route · Three observations"
    }

    private func notebookButton(_ title: String, _ icon: String, _ destination: ReserveSheet) -> some View {
        Button { sheet = destination } label: {
            Label(title, systemImage: icon)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(destination == .guide ? "openGuide" : "openJournal")
    }

    private var soundButton: some View {
        Button(action: session.toggleSound) {
            Image(systemName: session.sound ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.sound ? "Mute sound" : "Unmute sound")
    }

    private var playHUD: some View {
        HStack(alignment: .top) {
            HStack(spacing: 10) {
                Image("FrogCrest").resizable().scaledToFit().frame(width: 30, height: 29)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    FieldLabel(session.mode == .daily ? "DAILY EXPEDITION" : "DISTANCE", size: 9).foregroundStyle(Field.muted)
                    Text(String(format: "%03d", session.game.score))
                        .font(.system(size: 29, weight: .black, design: .monospaced))
                        .foregroundStyle(Field.paper).monospacedDigit()
                        .accessibilityIdentifier("score")
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Field.ink, in: RoundedRectangle(cornerRadius: 8))
            Spacer()
            if session.screen == .crossing {
                Button(action: session.pause) {
                    Image(systemName: "pause.fill").font(.system(size: 16, weight: .black))
                        .frame(width: 46, height: 46)
                        .foregroundStyle(Field.paper)
                        .background(Field.ink, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pause")
                .accessibilityIdentifier("pauseCrossing")
            }
        }
        .padding(.horizontal, 18).padding(.top, 5)
    }

    private var fieldPrompt: some View {
        VStack(alignment: .leading, spacing: 4) {
            if session.mode == .practice {
                FieldLabel("PRACTICE · " + String(session.practice.stepNumber) + " OF 3", size: 10)
                    .foregroundStyle(Field.lime)
                Text(session.practice.title).font(.system(.headline, design: .rounded, weight: .bold))
                    .accessibilityIdentifier("practiceTitle")
                Text(session.practice.instruction).font(.subheadline)
            } else if let survey = session.survey {
                FieldLabel("OBSERVATIONS · " + String(survey.count) + " OF 3", size: 10)
                    .foregroundStyle(Field.amber).accessibilityIdentifier("surveyCount")
                Text(survey.latestFind.map { "Recorded — " + $0 + ". Look for the next sign." }
                     ?? "Hop onto the amber sign on the grass.")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
        }
        .foregroundStyle(Field.paper)
        .padding(.horizontal, 15).padding(.vertical, 10)
        .frame(maxWidth: 420, alignment: .leading)
        .background(Field.ink.opacity(0.95), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 18).padding(.bottom, 8)
        .allowsHitTesting(false)
    }

    private var directionPad: some View {
        HStack(spacing: 3) {
            directionButton(.left, "arrow.left", "Left", "left")
            directionButton(.back, "arrow.down", "Back", "back")
            directionButton(.forward, "arrow.up", "Forward", "forward")
            directionButton(.right, "arrow.right", "Right", "right")
        }
        .padding(4)
        .background(Field.ink.opacity(0.94), in: RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 6)
    }

    private func directionButton(_ direction: TrailDirection, _ symbol: String,
                                 _ label: String, _ identifier: String) -> some View {
        Button { session.hop(direction) } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .black))
                .frame(width: 47, height: 44)
                .background(Field.muted.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                .foregroundStyle(direction == .forward ? Field.lime : Field.paper)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var resultPanel: some View {
        let paused = session.screen == .paused
        return footer {
            HStack {
                FieldLabel(paused ? "TRAIL BREAK" : resultKicker)
                    .foregroundStyle(Field.lime)
                Spacer()
                soundButton
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(paused ? "Take a breather" : resultTitle)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .accessibilityIdentifier("panelTitle")
                Text(paused ? "Continue from the same spot when you're ready." : resultDetail)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Field.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TrailButton(title: paused ? "Resume" : replayTitle,
                        symbol: paused ? "play.fill" : "arrow.clockwise") {
                if paused { session.resume() } else { session.start(session.mode == .daily ? .daily : .classic) }
            }
            .accessibilityIdentifier("primaryAction")
            Button("Main menu", action: session.returnToReserve)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("leaveCrossing")
        }
    }

    private var resultKicker: String {
        if session.mode == .practice { return "PRACTICE COMPLETE" }
        if session.mode == .daily { return "FIELD OBSERVATIONS" }
        return session.game.score > session.recordAtStart ? "NEW RECORD" : "CROSSING COMPLETE"
    }

    private var replayTitle: String {
        switch session.mode {
        case .classic: "Cross again"
        case .practice: "Start crossing"
        case .daily: "Try expedition again"
        }
    }

    private var resultTitle: String {
        if session.mode == .practice { return session.practice.title }
        if session.survey?.complete == true { return "Expedition complete!" }
        switch session.game.death {
        case .traffic: return "Hit by a car!"
        case .water: return "Missed the log!"
        case .sweptAway: return "Swept away!"
        case nil: return "End of the crossing"
        }
    }

    private var resultDetail: String {
        if session.mode == .practice { return session.practice.instruction }
        if let survey = session.survey {
            if survey.complete { return WetlandSurvey.finds.joined(separator: " · ") + ". All three observations added to your journal." }
            return "Observations: " + String(survey.count) + " of 3. The route stays the same for the rest of the day."
        }
        let hint: String
        switch session.game.death {
        case .traffic: hint = "Let the car pass, then hop across."
        case .water: hint = "Wait for a log to line up with you."
        case .sweptAway: hint = "Hop off the log before it reaches the edge."
        case nil: hint = ""
        }
        return "Distance — " + distance(session.game.score) + ". " + hint
    }

    private func footer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            TicketEdge().fill(Field.ink).frame(height: 6)
            VStack(alignment: .leading, spacing: 13, content: content)
                .padding(.horizontal, 22).padding(.top, 15).padding(.bottom, 10)
                .frame(maxWidth: 580)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Field.paper)
                .background(Field.ink.ignoresSafeArea(edges: .bottom))
        }
    }

    private func distance(_ value: Int) -> String {
        let suffix = value == 1 ? "row" : "rows"
        return "\(value) \(suffix)"
    }
}
