import XCTest
@testable import Mossbound

final class PracticeTrailTests: XCTestCase {
    @discardableResult
    private func hop(_ game: inout TrailGame, _ practice: inout PracticeTrail) -> PracticeTrail.Event? {
        XCTAssertTrue(game.move(.forward))
        game.update(0.16)
        return practice.observe(&game)
    }

    func testReachFarBankThroughRealHazardsAndFinishOnce() {
        var practice = PracticeTrail()
        var game = PracticeTrail.makeGame()
        XCTAssertEqual(practice.stepNumber, 1)
        XCTAssertNil(hop(&game, &practice))
        XCTAssertEqual(practice.stepNumber, 2)
        XCTAssertNil(hop(&game, &practice))
        XCTAssertEqual(game.lane(at: 2).kind, .road)
        XCTAssertNil(hop(&game, &practice))
        XCTAssertEqual(practice.stepNumber, 3)
        XCTAssertNil(hop(&game, &practice))
        XCTAssertEqual(game.lane(at: 4).kind, .river)
        game.update(0.20)
        XCTAssertLessThan(game.playerX, 0)
        XCTAssertEqual(hop(&game, &practice), .completed)
        XCTAssertTrue(practice.isComplete)
        XCTAssertNil(practice.observe(&game))
    }

    func testRoadAndWaterMistakesReturnToLastBankAndRemainPlayable() {
        var practice = PracticeTrail()
        var game = PracticeTrail.makeGame()
        hop(&game, &practice)
        for _ in 0..<4 { game.update(0.25) }
        XCTAssertEqual(hop(&game, &practice), .retry(.traffic))
        XCTAssertNil(game.death)
        XCTAssertEqual(game.playerY, 1)

        hop(&game, &practice)
        hop(&game, &practice)
        for _ in 0..<11 { game.update(0.25) }
        XCTAssertEqual(hop(&game, &practice), .retry(.water))
        XCTAssertNil(game.death)
        XCTAssertEqual(game.playerY, 3)
        hop(&game, &practice)
        XCTAssertEqual(hop(&game, &practice), .completed)
    }

    func testCurrentReturnsToRiverCheckpoint() {
        var practice = PracticeTrail()
        var game = PracticeTrail.makeGame()
        for _ in 0..<4 { hop(&game, &practice) }
        var event: PracticeTrail.Event?
        for _ in 0..<24 where event == nil {
            game.update(0.25)
            event = practice.observe(&game)
        }
        XCTAssertEqual(event, .retry(.sweptAway))
        XCTAssertEqual(game.playerY, 3)
        XCTAssertFalse(practice.isComplete)
    }

    func testLandingEventsIncludeBufferedHopsAndExcludeWaitingAndCollisions() {
        var cells: [[Int]] = []
        let record: (Int, Int) -> Void = { cells.append([$0, $1]) }
        var game = TrailGame(seed: 1)
        game.update(0.03, onLanding: record)
        XCTAssertTrue(game.move(.right))
        XCTAssertTrue(game.move(.forward))
        for _ in 0..<3 { game.update(0.20, onLanding: record) }
        XCTAssertEqual(cells, [[1, 0], [1, 1]])

        game = TrailGame(seed: 1)
        cells.removeAll()
        for _ in 0..<2 {
            game.move(.forward)
            game.update(0.16, onLanding: record)
        }
        XCTAssertEqual(game.death, .traffic)
        XCTAssertEqual(cells, [[0, 1]])
    }
}
