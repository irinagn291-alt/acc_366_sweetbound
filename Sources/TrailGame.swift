import Foundation

enum TrailDirection { case forward, back, left, right }
enum TrailDeath { case traffic, water, sweptAway }
enum TrailKind { case grass, road, river }

struct TrailLane {
    let kind: TrailKind
    let blocked: [Int]
    let speed: Double
    fileprivate var spacing = 0.0
    fileprivate var length = 0.0
    fileprivate var offset = 0.0
}

struct TrailMover {
    let x: Double
    let length: Double
    let id: Int
}

struct TrailGame {
    private struct Hop {
        let fromX: Double
        let fromY: Int
        let toX: Double
        let toY: Int
        var elapsed = 0.0
    }

    private static let hopDuration = 0.16
    private let seed: UInt64
    private let practiceRoute: Bool
    private var hop: Hop?
    private var bufferedMove: TrailDirection?
    private(set) var playerX = 0.0
    private(set) var playerY = 0.0
    private(set) var hopHeight = 0.0
    private(set) var time = 0.0
    private(set) var score = 0
    private(set) var death: TrailDeath?
    private(set) var facing: TrailDirection = .forward

    init(seed: UInt64) {
        self.seed = seed
        practiceRoute = false
    }

    init(practiceBank: PracticeTrail.Bank) {
        seed = 0
        practiceRoute = true
        playerY = Double(practiceBank.rawValue)
        score = practiceBank.rawValue
    }

    // Each row owns its terrain and traffic pattern, so revisiting it requires no history.
    private func noise(_ row: Int, _ channel: UInt64) -> UInt64 {
        var bits = seed &+ UInt64(row) &* 0x9E3779B97F4A7C15 &+ channel &* 0xD1B54A32D192ED03
        bits = (bits ^ (bits >> 30)) &* 0xBF58476D1CE4E5B9
        bits = (bits ^ (bits >> 27)) &* 0x94D049BB133111EB
        return bits ^ (bits >> 31)
    }

    func lane(at row: Int) -> TrailLane {
        if practiceRoute {
            switch row {
            case 2:
                return TrailLane(kind: .road, blocked: [], speed: 1.3,
                                 spacing: 5.7, length: 1.4, offset: -1.8)
            case 4:
                return TrailLane(kind: .river, blocked: [], speed: -0.95,
                                 spacing: 4.95, length: 2.85, offset: 0.68)
            default:
                return TrailLane(kind: .grass, blocked: [], speed: 0)
            }
        }
        guard row > 1 else { return TrailLane(kind: .grass, blocked: [], speed: 0) }
        let group = (row - 2) / 3
        let index = (row - 2) % 3
        if index == 2 || (group >= 2 && index == 1 && noise(group, 1) % 5 == 0) {
            let rock = Int(noise(row, 2) % 9) - 4
            return TrailLane(kind: .grass, blocked: [rock], speed: 0)
        }
        let river = group < 2 ? group == 1 : noise(group, 3) % 5 < 2
        let difficulty = min(1.0, Double(row - 2) / 90)
        let variation = Double(noise(row, 4) % 100) / 100
        let magnitude = river ? 0.85 + 0.45 * variation : 1.45 + 0.7 * variation + difficulty
        let speed = row.isMultiple(of: 2) ? magnitude : -magnitude
        let length = river ? 2.75 + 0.35 * variation : 1.23 + 0.45 * variation
        let spacing = length + (river ? 1.75 : 3.4) + Double(noise(row, 5) % 70) / 100
        let offset = Double(noise(row, 6) % 1000) * spacing / 1000
        return TrailLane(kind: river ? .river : .road, blocked: [], speed: speed,
                         spacing: spacing, length: length, offset: offset)
    }

    func movers(at row: Int) -> [TrailMover] {
        let lane = lane(at: row)
        guard lane.kind != .grass else { return [] }
        let origin = lane.offset + time * lane.speed
        let first = Int(floor((-8 - origin) / lane.spacing))
        let last = Int(ceil((8 - origin) / lane.spacing))
        return (first...last).map { index in
            let id = index >= 0 ? index * 2 : -index * 2 - 1
            return TrailMover(x: origin + Double(index) * lane.spacing, length: lane.length, id: id)
        }
    }

    @discardableResult
    mutating func move(_ direction: TrailDirection) -> Bool {
        guard death == nil else { return false }
        if hop != nil {
            guard bufferedMove == nil else { return false }
            bufferedMove = direction
            return true
        }
        let row = Int(playerY.rounded())
        var toX = playerX
        var toY = row
        switch direction {
        case .forward: toY += 1
        case .back: toY -= 1
        case .left: toX -= 1
        case .right: toX += 1
        }
        if toY != row { toX = min(4, max(-4, toX.rounded())) }
        guard abs(toX) <= 4.48, toY >= max(0, score - 4),
              !lane(at: toY).blocked.contains(Int(toX.rounded())) else { return false }
        hop = Hop(fromX: playerX, fromY: row, toX: toX, toY: toY)
        facing = direction
        return true
    }

    mutating func update(_ dt: Double, onLanding: ((Int, Int) -> Void)? = nil) {
        guard dt > 0, dt.isFinite, death == nil else { return }
        // Limit catch-up after an OS stall. Small steps prevent fast cars tunneling through the frog.
        var remaining = min(dt, 0.25)
        while remaining > 0, death == nil {
            var step = min(remaining, 1.0 / 90)
            if let hop { step = min(step, Self.hopDuration - hop.elapsed) }
            remaining -= step
            time += step
            advance(step, onLanding: onLanding)
        }
    }

    private func distanceToMover(in lane: TrailLane) -> Double {
        let offset = playerX - lane.offset - time * lane.speed
        return abs(offset - (offset / lane.spacing).rounded() * lane.spacing)
    }

    private mutating func advance(_ dt: Double, onLanding: ((Int, Int) -> Void)?) {
        let wasHopping = hop != nil
        if var current = hop {
            current.elapsed += dt
            let progress = min(1, current.elapsed / Self.hopDuration)
            playerX = current.fromX + (current.toX - current.fromX) * progress
            playerY = Double(current.fromY) + Double(current.toY - current.fromY) * progress
            hopHeight = 0.46 * 4 * progress * (1 - progress)
            hop = progress < 1 ? current : nil
        } else {
            let lane = lane(at: Int(playerY.rounded()))
            if lane.kind == .river { playerX += lane.speed * dt }
        }

        let row = Int(playerY.rounded())
        let lane = lane(at: row)
        switch lane.kind {
        case .road:
            if abs(playerY - Double(row)) < 0.43, distanceToMover(in: lane) < lane.length / 2 + 0.19 {
                death = .traffic
            }
        case .river where hop == nil:
            if abs(playerX) >= 4.5 {
                death = .sweptAway
            } else if distanceToMover(in: lane) > lane.length / 2 + 0.04 {
                death = .water
            }
        default: break
        }
        guard death == nil, wasHopping, hop == nil else { return }
        score = max(score, row)
        onLanding?(Int(playerX.rounded()), row)
        if let next = bufferedMove {
            bufferedMove = nil
            move(next)
        }
    }
}
