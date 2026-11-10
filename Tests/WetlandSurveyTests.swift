import XCTest
@testable import Mossbound

final class WetlandSurveyTests: XCTestCase {
    private let day = TrailDay(date: Date(timeIntervalSince1970: 0), timeZone: .gmt)

    func testThreeFindsOnAPlayableDailyCrossing() {
        var survey = WetlandSurvey(day: day)
        var game = TrailGame(seed: day.seed)
        let terrain = game
        // Recorded crossing for this date. The bank on row 4 requires moving left.
        let route: [TrailDirection] = [.forward, .forward, .forward, .forward, .left, .left,
                                       .left, .forward, .right, .forward, .forward]
        var finds: [String] = []
        for move in route {
            XCTAssertTrue(game.move(move))
            game.update(0.16) { column, row in
                let previous = survey.count
                survey.observe(column: column, row: row, lane: terrain.lane(at: row))
                if survey.count > previous, let name = survey.latestFind { finds.append(name) }
            }
            XCTAssertNil(game.death)
        }
        XCTAssertEqual(finds, ["Heron feather", "Beaver tracks", "Dragonfly over water"])
        XCTAssertTrue(survey.complete)
        XCTAssertEqual(game.score, 7)
        XCTAssertNil(survey.signColumn(row: 10, lane: game.lane(at: 10)))
        survey.observe(column: 0, row: 10, lane: game.lane(at: 10))
        XCTAssertEqual(survey.count, 3)
    }

    func testMissedTileRepeatedLandingAndUnsafeRowsDoNotAwardFinds() throws {
        var survey = WetlandSurvey(day: day)
        let game = TrailGame(seed: day.seed)
        let first = game.lane(at: 1)
        XCTAssertEqual(survey.signColumn(row: 1, lane: first), 0)
        survey.observe(column: 1, row: 1, lane: first)
        XCTAssertNil(survey.latestFind)
        survey.observe(column: 0, row: 1, lane: first)
        survey.observe(column: 0, row: 1, lane: first)
        XCTAssertEqual(survey.count, 1)
        XCTAssertNil(survey.signColumn(row: 1, lane: first))

        for row in [2, 3, 5, 6] {
            let lane = game.lane(at: row)
            XCTAssertNotEqual(lane.kind, .grass)
            XCTAssertNil(survey.signColumn(row: row, lane: lane))
            survey.observe(column: 0, row: row, lane: lane)
        }
        // A missed bank does not prevent collection on a later one.
        let later = game.lane(at: 7)
        let column = try XCTUnwrap(survey.signColumn(row: 7, lane: later))
        survey.observe(column: column, row: 7, lane: later)
        XCTAssertEqual(survey.count, 2)
    }

    func testRepeatedDailySeedsPutEverySignOnAnUnblockedBank() throws {
        for offset in 0..<7 {
            let date = Date(timeIntervalSince1970: Double(offset) * 86_400)
            let day = TrailDay(date: date, timeZone: .gmt)
            let replayDay = TrailDay(date: date.addingTimeInterval(3_600), timeZone: .gmt)
            let game = TrailGame(seed: day.seed)
            let replay = TrailGame(seed: replayDay.seed)
            let survey = WetlandSurvey(day: day)
            let replaySurvey = WetlandSurvey(day: replayDay)
            for row in stride(from: 1, through: 100, by: 3) {
                let lane = game.lane(at: row)
                let column = try XCTUnwrap(survey.signColumn(row: row, lane: lane))
                XCTAssertEqual(column, replaySurvey.signColumn(row: row, lane: replay.lane(at: row)))
                XCTAssertEqual(lane.kind, .grass)
                XCTAssertFalse(lane.blocked.contains(column))
                XCTAssertTrue((-3...3).contains(column))
            }
        }
    }
}
