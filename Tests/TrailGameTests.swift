import XCTest
@testable import Mossbound

final class TrailGameTests: XCTestCase {
    private func opening(seed: UInt64, hops: Int) -> TrailGame {
        var game = TrailGame(seed: seed)
        for _ in 0..<hops {
            game.move(.forward)
            game.update(0.16)
        }
        return game
    }

    func testOneInputIsBufferedAndRevisitingRowsDoesNotFarmPoints() {
        var game = TrailGame(seed: 0)
        XCTAssertFalse(game.move(.back))
        XCTAssertTrue(game.move(.forward))
        XCTAssertTrue(game.move(.back))
        XCTAssertFalse(game.move(.right))
        game.update(0.20)
        game.update(0.20)
        XCTAssertEqual(game.score, 1)
        XCTAssertEqual(game.playerY, 0)
        XCTAssertEqual(game.playerX, 0)
        XCTAssertEqual(game.hopHeight, 0)
    }

    func testFieldEdgesAndRocksBlockHops() {
        var game = TrailGame(seed: 0)
        for _ in 0..<4 {
            XCTAssertTrue(game.move(.left))
            game.update(0.20)
        }
        XCTAssertEqual(game.playerX, -4)
        XCTAssertFalse(game.move(.left))

        game = opening(seed: 0, hops: 4)
        XCTAssertEqual(game.score, 4)
        let rock = game.lane(at: 4).blocked[0]
        let direction: TrailDirection = rock > 0 ? .right : .left
        for _ in 1..<abs(rock) {
            XCTAssertTrue(game.move(direction))
            game.update(0.20)
        }
        XCTAssertFalse(game.move(direction))
    }

    func testTrafficHitsMovingAndStationaryPlayerAndFreezesRun() {
        var game = opening(seed: 1, hops: 2)
        XCTAssertEqual(game.death, .traffic)
        XCTAssertEqual(game.score, 1)
        let endTime = game.time
        XCTAssertFalse(game.move(.left))
        game.update(0.25)
        XCTAssertEqual(game.time, endTime)

        game = opening(seed: 0, hops: 2)
        XCTAssertNil(game.death)
        for _ in 0..<20 { game.update(0.25) }
        XCTAssertEqual(game.death, .traffic)
    }

    func testRiverRequiresLandingOnLogAndCarriesPlayerToBankEdge() {
        let splash = opening(seed: 7, hops: 5)
        XCTAssertEqual(splash.death, .water)
        XCTAssertEqual(splash.score, 4)

        var riding = opening(seed: 0, hops: 5)
        XCTAssertNil(riding.death)
        XCTAssertEqual(riding.score, 5)
        let startX = riding.playerX
        riding.update(0.2)
        XCTAssertEqual(riding.playerX - startX, riding.lane(at: 5).speed * 0.2, accuracy: 0.0001)
        for _ in 0..<30 { riding.update(0.25) }
        XCTAssertEqual(riding.death, .sweptAway)
    }
}
