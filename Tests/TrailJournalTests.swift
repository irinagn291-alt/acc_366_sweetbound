import XCTest
@testable import Mossbound

final class TrailJournalTests: XCTestCase {
    private func isolatedDefaults() -> UserDefaults {
        let name = "MossboundTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testLocalMidnightChangesRouteAndSameCalendarDateHasSameSeed() throws {
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-11-04T20:59:59Z"))
        let moscow = try XCTUnwrap(TimeZone(secondsFromGMT: 3 * 3600))
        let utc = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let today = TrailDay(date: date, timeZone: moscow)
        let tomorrow = TrailDay(date: date.addingTimeInterval(1), timeZone: moscow)
        XCTAssertEqual(today.id, "2026-11-04")
        XCTAssertEqual(tomorrow.id, "2026-11-05")
        XCTAssertNotEqual(today.seed, tomorrow.seed)
        XCTAssertEqual(today, TrailDay(date: date.addingTimeInterval(1), timeZone: utc))
    }

    func testRestoredJournalCountsFinishedRunOnceAndKeepsBestByStartingDay() {
        let defaults = isolatedDefaults()
        let first = TrailDay(date: Date(timeIntervalSince1970: 0), timeZone: .gmt)
        let next = TrailDay(date: Date(timeIntervalSince1970: 86_400), timeZone: .gmt)
        let firstRun = UUID()
        var journal = TrailJournal(defaults: defaults)
        var otherWindow = journal
        journal.record(runID: firstRun, score: 13, day: first, surveyCompleted: true)
        otherWindow.record(runID: UUID(), score: 0, day: next)
        otherWindow.record(runID: UUID(), score: 4, day: first)
        journal = TrailJournal(defaults: defaults)
        journal.record(runID: firstRun, score: 13, day: first, surveyCompleted: true)
        journal.record(runID: UUID(), score: 5, day: nil)

        XCTAssertEqual(journal.completedRuns, 4)
        XCTAssertEqual(journal.totalRows, 22)
        XCTAssertEqual(journal.dailyBest(for: first), 13)
        XCTAssertEqual(journal.dailyBest(for: next), 0)
        XCTAssertTrue(journal.surveyCompleted(for: first))
        XCTAssertFalse(journal.surveyCompleted(for: next))
        XCTAssertEqual(journal.completedSurveys, 1)

        journal.record(runID: UUID(), score: 14, day: first, surveyCompleted: true)
        XCTAssertEqual(journal.completedSurveys, 1)
        journal.record(runID: UUID(), score: 15, day: next, surveyCompleted: true)
        XCTAssertEqual(TrailJournal(defaults: defaults).completedSurveys, 2)
    }

    func testExistingPersonalBestUnlocksDistanceBadgesAlongsideNewJournalGoals() {
        let defaults = isolatedDefaults()
        var journal = TrailJournal(defaults: defaults)
        XCTAssertEqual(journal.milestones(best: 7).filter(\.unlocked).map(\.id), ["meadow", "river"])
        XCTAssertNil(journal.dailyBest(for: TrailDay()))

        journal.record(runID: UUID(), score: 60, day: nil)
        XCTAssertEqual(journal.milestones(best: 60).filter(\.unlocked).map(\.id), ["meadow", "river", "distance"])
        journal.record(runID: UUID(), score: 15, day: TrailDay(), surveyCompleted: true)
        XCTAssertTrue(journal.milestones(best: 60).allSatisfy { $0.unlocked && $0.progress == $0.goal })
    }

    func testPartialFindsSurviveAbandonmentRelaunchAndWritesFromAnotherWindow() {
        let defaults = isolatedDefaults()
        var survey = TrailJournal(defaults: defaults)
        var otherWindow = survey
        survey.discoverFinds(upTo: 2)
        XCTAssertEqual(TrailJournal(defaults: defaults).discoveredFindCount, 2)
        XCTAssertEqual(TrailJournal(defaults: defaults).completedRuns, 0)

        otherWindow.record(runID: UUID(), score: 5, day: nil)
        otherWindow.discoverFinds(upTo: 1)
        XCTAssertEqual(otherWindow.discoveredFindCount, 2)
        survey.discoverFinds(upTo: 99)
        let restored = TrailJournal(defaults: defaults)
        XCTAssertEqual(restored.discoveredFindCount, WetlandSurvey.finds.count)
        XCTAssertEqual(restored.totalRows, 5)
        XCTAssertEqual(restored.completedSurveys, 0)
    }

    func testLegacySurveyCompletionRestoresAllFindsWithoutLosingStats() throws {
        let defaults = isolatedDefaults()
        let legacy: [String: Any] = [
            "completedRuns": 2, "totalRows": 19, "recentRunIDs": [],
            "days": ["2026-11-03": ["best": 12, "surveyCompleted": true]]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: legacy, format: .binary, options: 0)
        defaults.set(data, forKey: "mossbound.journal.v1")
        var journal = TrailJournal(defaults: defaults)
        XCTAssertEqual(journal.discoveredFindCount, WetlandSurvey.finds.count)
        XCTAssertEqual(journal.completedRuns, 2)
        journal.discoverFinds(upTo: 1)
        XCTAssertEqual(defaults.data(forKey: "mossbound.journal.v1"), data)
        journal.record(runID: UUID(), score: 6, day: nil)
        XCTAssertEqual(TrailJournal(defaults: defaults).discoveredFindCount, WetlandSurvey.finds.count)
        XCTAssertEqual(journal.totalRows, 25)
    }
}
