import SwiftUI

/// The marsh is drawn entirely in world coordinates, including the moving hazards.
struct TrailBoard: View {
    let game: TrailGame
    var survey: WetlandSurvey? = nil

    var body: some View {
        Canvas(opaque: true) { context, size in
            guard size.width > 0, size.height > 0 else { return }
            MarshPainter(canvas: context, size: size, game: game, survey: survey).draw()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct Ink {
    let color: Color

    init(_ rgb: UInt32, alpha: Double = 1) {
        color = Color(.sRGB, red: Double(rgb >> 16 & 255) / 255,
                      green: Double(rgb >> 8 & 255) / 255,
                      blue: Double(rgb & 255) / 255, opacity: alpha)
    }
}

private struct Paint {
    let top: Ink
    let front: Ink
    let side: Ink

    init(_ a: UInt32, _ b: UInt32, _ c: UInt32) {
        top = Ink(a)
        front = Ink(b)
        side = Ink(c)
    }
}

private enum Marsh {
    static let moss = [Ink(0x96B865), Ink(0x9ABB68), Ink(0x92B361)]
    static let grassShade = Ink(0x709B54)
    static let grassLight = Ink(0xBDD180)
    static let grassDeep = Ink(0x567C48)
    static let flowers = [Ink(0xF6D980), Ink(0xF2D3B0), Ink(0xDDE4AE)]
    static let road = [Ink(0x515762), Ink(0x4E5660)]
    static let roadLight = Ink(0x697279)
    static let asphaltEdge = Ink(0x3C444B)
    static let shoulder = Ink(0xB8AA80)
    static let stripe = Ink(0xE9CF88)
    static let stream = [Ink(0x539699), Ink(0x498F95)]
    static let wave = Ink(0x83BFBA)
    static let glint = Ink(0xB3D9C9)
    static let current = Ink(0x39848D)
    static let bank = Ink(0x466E5B)
    static let softShadow = Ink(0x264A3E, alpha: 0.24)
    static let waterShadow = Ink(0x245764, alpha: 0.55)
    static let trunk = Paint(0xAE8B5E, 0x796142, 0x5A5139)
    static let pine = [
        Paint(0x84A964, 0x4F8059, 0x356B52),
        Paint(0x749F68, 0x477B58, 0x32634D)
    ]
    static let pineTip = Paint(0xA1BC72, 0x6E9C64, 0x4D825A)
    static let shrub = Paint(0xA0B45D, 0x738E49, 0x567B44)
    static let stone = Paint(0xA6AB91, 0x838A79, 0x687467)
    static let bark = Paint(0xB58856, 0x8D6646, 0x6D543D)
    static let wood = Ink(0xD0AD72)
    static let grain = Ink(0x946B44)
    static let tires = Paint(0x48505A, 0x2D353F, 0x242D35)
    static let hub = Ink(0xA0A7A5)
    static let cars = [
        Paint(0xED9674, 0xBA624E, 0x9A5547),
        Paint(0xE8C06D, 0xBD914C, 0x9B7743),
        Paint(0x98C8BE, 0x65988F, 0x54837F),
        Paint(0xCFADBD, 0xA27F93, 0x856B83)
    ]
    static let glass = Paint(0xC9DDD4, 0x567786, 0x466A78)
    static let headlight = Ink(0xFFF2BF)
    static let taillight = Ink(0xA74640)
    static let frog = Paint(0xCFEB70, 0x9BC74C, 0x75A64C)
    static let frogHead = Paint(0xD3EA76, 0xABCD54, 0x91B949)
    static let foot = Paint(0x94BD53, 0x6A9648, 0x598D4D)
    static let eye = Paint(0xFFF7CC, 0xF3EEC0, 0xDADCB1)
    static let scarf = Paint(0xFF9B68, 0xDA7052, 0xBD5F48)
    static let pupil = Ink(0x294239)
}

// Projection basis: the x-axis follows the traffic, y points deeper into the marsh,
// and z raises a point above the surface.
private struct MarshPainter {
    let canvas: GraphicsContext
    let size: CGSize
    let game: TrailGame
    let survey: WetlandSurvey?
    let unit: Double
    let cameraX: Double
    let cameraY: Double

    init(canvas: GraphicsContext, size: CGSize, game: TrailGame, survey: WetlandSurvey?) {
        self.canvas = canvas
        self.size = size
        self.game = game
        self.survey = survey
        unit = min(size.width / 9.8, size.height / 12.0)
        cameraX = game.playerX * 0.20
        cameraY = game.playerY
    }

    func point(_ x: Double, _ y: Double, _ z: Double = 0) -> CGPoint {
        let dx = x - cameraX
        let dy = y - cameraY
        return CGPoint(x: size.width * 0.5 + unit * (dx + dy * 0.36),
                       y: size.height * 0.62 - unit * (dx * 0.19 + dy * 0.76 + z * 0.89))
    }

    func polygon(_ vertices: [CGPoint], _ ink: Ink) {
        var path = Path()
        path.addLines(vertices)
        path.closeSubpath()
        canvas.fill(path, with: .color(ink.color))
    }

    func patch(_ x: Double, _ y: Double, _ w: Double, _ d: Double, _ ink: Ink, z: Double = 0) {
        polygon([point(x, y, z), point(x + w, y, z),
                 point(x + w, y + d, z), point(x, y + d, z)], ink)
    }

    func front(_ x: Double, _ y: Double, _ z: Double, _ w: Double, _ h: Double, _ ink: Ink) {
        polygon([point(x, y, z), point(x + w, y, z),
                 point(x + w, y, z + h), point(x, y, z + h)], ink)
    }

    func side(_ x: Double, _ y: Double, _ z: Double, _ d: Double, _ h: Double, _ ink: Ink) {
        polygon([point(x, y, z), point(x, y + d, z),
                 point(x, y + d, z + h), point(x, y, z + h)], ink)
    }

    /// x and y denote the center of the footprint.
    func box(_ x: Double, _ y: Double, _ z: Double, _ w: Double, _ d: Double, _ h: Double, _ paint: Paint) {
        let left = x - w / 2, near = y - d / 2
        side(left + w, near, z, d, h, paint.side)
        front(left, near, z, w, h, paint.front)
        patch(left, near, w, d, paint.top, z: z + h)
    }

    func noise(_ x: Int, _ y: Int) -> UInt32 {
        var value = UInt32(truncatingIfNeeded: x) &* 0x9E3779B1
        value ^= UInt32(truncatingIfNeeded: y) &* 0x85EBCA77
        value ^= value >> 16
        value &*= 0x7FEB352D
        return value ^ (value >> 15)
    }

    func visibleColumns(_ row: Int) -> ClosedRange<Int> {
        let middle = cameraX - (Double(row) - cameraY) * 0.36
        let radius = size.width / (2 * unit) + 1.6
        return Int(floor(middle - radius))...Int(ceil(middle + radius))
    }

    func draw() {
        let extent = size.height / unit
        let span = (size.width / unit) * 0.15
        let near = Int(floor(cameraY - extent * 0.60 - span - 3))
        let far = Int(ceil(cameraY + extent * 0.90 + span + 3))
        var objects: [(depth: Double, prop: Prop)] = []
        for row in (near...far).reversed() {
            let lane = game.lane(at: row)
            let columns = visibleColumns(row)
            ground(row, lane, columns: columns)
            if let survey, let column = survey.signColumn(row: row, lane: lane), columns.contains(column) {
                objects.append((Double(row) * 0.76 + Double(column) * 0.19, .sign(column, row, survey.count)))
            }
            for column in columns {
                let screen = point(Double(column), Double(row))
                guard screen.y >= -unit, screen.y <= size.height + unit * 2.0,
                      screen.x >= -unit, screen.x <= size.width + unit else { continue }
                let seed = noise(column, row)
                let blocked = lane.blocked.contains(column)
                let isWild = abs(column) > 4 && seed % 4 != 0
                let backwoods = row < -1 && seed % 6 == 1
                if lane.kind == .grass, blocked || isWild || backwoods {
                    objects.append((Double(row) * 0.76 + Double(column) * 0.19,
                                    .plant(x: column, y: row, seed: seed)))
                }
            }
            if lane.kind != .grass {
                for mover in game.movers(at: row) {
                    guard mover.x + mover.length / 2 >= Double(columns.lowerBound),
                          mover.x - mover.length / 2 <= Double(columns.upperBound) else { continue }
                    let prop: Prop = lane.kind == .river ? .log(mover, row) : .car(mover, row, lane.speed > 0)
                    objects.append((Double(row) * 0.76 + mover.x * 0.19, prop))
                }
            }
        }
        objects.append((game.playerY * 0.76 + game.playerX * 0.19 - 0.34, .frog))
        for item in objects.sorted(by: { $0.depth > $1.depth }) {
            switch item.prop {
            case let .plant(x, y, seed): plant(Double(x), Double(y), seed: seed)
            case let .log(mover, row): log(mover, row: row)
            case let .car(mover, row, right): car(mover, row: row, right: right)
            case let .sign(column, row, find): surveySign(Double(column), Double(row), find: find)
            case .frog: frog()
            }
        }
    }

    private enum Prop {
        case plant(x: Int, y: Int, seed: UInt32)
        case log(TrailMover, Int)
        case car(TrailMover, Int, Bool)
        case sign(Int, Int, Int)
        case frog
    }

    // Silhouettes match the order of the entries in the survey notebook.
    private static let surveyStamps: [Path] = [
        ["....###", "...####", "..###.#", ".#####.", ".###...", "..#....", ".#....."],
        [".#...#.", ".#.#.#.", "...#...", "..###..", ".#####.", ".#####.", "..###.."],
        [".#...#.", "..#.#..", "##.#.##", "..###..", "##.#.##", "...#...", "...#..."]
    ].map { rows in
        var stamp = Path()
        for (y, row) in rows.enumerated() {
            for (x, pixel) in row.enumerated() where pixel == "#" {
                stamp.addRect(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        return stamp
    }

    func surveySign(_ x: Double, _ y: Double, find: Int) {
        patch(x - 0.3, y - 0.21, 0.60, 0.42, Marsh.softShadow)
        let lift = 0.46 + 0.07 * sin(game.time * 3.2 + y)
        let center = point(x, y, lift)
        var token = canvas
        token.translateBy(x: center.x, y: center.y)
        token.scaleBy(x: unit * 0.038, y: unit * 0.038)
        var coin = Path()
        coin.addLines([CGPoint(x: -5, y: -9), CGPoint(x: 5, y: -9), CGPoint(x: 9, y: -5),
                       CGPoint(x: 9, y: 5), CGPoint(x: 5, y: 9), CGPoint(x: -5, y: 9),
                       CGPoint(x: -9, y: 5), CGPoint(x: -9, y: -5)])
        coin.closeSubpath()
        token.fill(coin, with: .color(Ink(0x493A29).color))
        token.scaleBy(x: 0.83, y: 0.83)
        token.fill(coin, with: .color(Ink(0xFFD76F).color))
        token.translateBy(x: -5.25, y: -5.25)
        token.scaleBy(x: 1.5, y: 1.5)
        token.fill(Self.surveyStamps[find], with: .color(Ink(0x573C26).color))
    }

    func ground(_ row: Int, _ lane: TrailLane, columns: ClosedRange<Int>) {
        let y = Double(row) - 0.5
        let x = Double(columns.lowerBound) - 1
        let width = Double(columns.count) + 1
        let variation = Int(noise(71, row) % 2)
        let nearKind = game.lane(at: row - 1).kind
        let farKind = game.lane(at: row + 1).kind
        switch lane.kind {
        case .grass:
            patch(x, y - 0.012, width, 1.025, Marsh.moss[Int(noise(11, row) % 3)])
        case .road:
            patch(x, y - 0.012, width, 1.025, Marsh.road[variation])
            if nearKind != .road {
                patch(x, y, width, 0.095, Marsh.shoulder)
                patch(x, y + 0.095, width, 0.035, Marsh.asphaltEdge)
            } else {
                for column in columns where column.isMultiple(of: 2) {
                    patch(Double(column) - 0.37, y - 0.025, 0.81, 0.047, Marsh.stripe)
                }
            }
            if farKind != .road {
                patch(x, y + 0.91, width, 0.09, Marsh.shoulder)
                patch(x, y + 0.865, width, 0.045, Marsh.asphaltEdge)
            }
        case .river:
            patch(x, y - 0.012, width, 1.025, Marsh.stream[variation])
            if farKind != .river {
                patch(x, y + 0.86, width, 0.14, Marsh.bank)
                patch(x, y + 0.80, width, 0.06, Marsh.current)
            }
            if nearKind != .river {
                patch(x, y, width, 0.07, Marsh.current)
            }
        }

        for column in columns {
            let screenY = point(Double(column), Double(row)).y
            guard screenY >= -unit, screenY <= size.height + unit else { continue }
            let seed = noise(column, row)
            let p = Double(column) + (Double(seed >> 8 & 255) / 255 - 0.5) * 0.62
            let q = Double(row) + (Double(seed >> 16 & 255) / 255 - 0.5) * 0.56
            switch lane.kind {
            case .grass:
                if seed % 3 == 0 {
                    patch(p - 0.12, q, 0.24, 0.055, Marsh.grassShade)
                    patch(p + 0.07, q + 0.06, 0.12, 0.055, Marsh.grassLight)
                }
                if seed % 8 == 1 || abs(column) > 4 && seed % 5 == 0 {
                    let base = point(p, q)
                    polygon([base, point(p - 0.12, q, 0.16), point(p - 0.025, q, 0.07),
                             point(p + 0.025, q, 0.21), point(p + 0.075, q, 0.07),
                             point(p + 0.17, q, 0.14), point(p + 0.095, q)], Marsh.grassShade)
                }
                if seed % 11 == 2 {
                    front(p, q, 0, 0.033, 0.16, Marsh.grassDeep)
                    patch(p - 0.045, q - 0.04, 0.12, 0.095, Marsh.flowers[Int(seed % 3)], z: 0.16)
                    patch(p + 0.16, q + 0.09, 0.078, 0.065, Marsh.flowers[Int(seed % 3)], z: 0.08)
                }
                if abs(column) == 4, row.isMultiple(of: 2) {
                    let edge = Double(column) + (column < 0 ? -0.48 : 0.48)
                    patch(edge, Double(row) - 0.28, 0.055, 0.34, Marsh.grassShade)
                }
            case .road:
                if seed % 7 == 0 {
                    patch(p, q, 0.15, 0.025, Marsh.roadLight)
                    patch(p + 0.13, q + 0.02, 0.07, 0.02, Marsh.roadLight)
                }
            case .river:
                guard seed % 3 != 1 else { continue }
                let pulse = sin(game.time * 1.5 + Double(seed & 31))
                let drift = pulse * 0.13
                patch(p + drift, q, 0.23 + Double(seed % 11) * 0.033, 0.036, Marsh.wave)
                if seed % 4 == 0 {
                    patch(p + drift + 0.16, q + 0.07, 0.14, 0.027, Marsh.glint)
                }
            }
        }
    }

    func plant(_ x: Double, _ y: Double, seed: UInt32) {
        let small = seed % 7 == 2
        let boulder = seed % 7 == 0
        let scale = 0.85 + Double((seed >> 8) % 5) * 0.045
        let h = (small || boulder) ? 0.50 : 1.34 * scale
        polygon([point(x - 0.38, y - 0.34), point(x + 0.24, y - 0.34),
                 point(x + 0.32 + h * 0.42, y - 0.12),
                 point(x + 0.27 + h * 0.40, y + h * 0.35),
                 point(x - 0.19, y + 0.27)], Marsh.softShadow)
        if boulder {
            box(x, y, 0, 0.68, 0.5, 0.27, Marsh.stone)
            box(x - 0.045, y + 0.025, 0.27, 0.49, 0.43, 0.13, Marsh.stone)
            patch(x - 0.16, y, 0.21, 0.14, Marsh.grassShade, z: 0.405)
            box(x + 0.34, y - 0.24, 0, 0.22, 0.20, 0.11, Marsh.stone)
        } else if small {
            box(x, y, 0.04, 0.70, 0.55, 0.32, Marsh.shrub)
            box(x - 0.045, y + 0.03, 0.36, 0.50, 0.37, 0.16, Marsh.shrub)
            front(x - 0.21, y - 0.28, 0.20, 0.07, 0.055, Marsh.flowers[0])
            front(x + 0.10, y - 0.28, 0.15, 0.08, 0.065, Marsh.flowers[0])
        } else {
            let leaf = Marsh.pine[Int(seed % 2)]
            box(x, y, 0, 0.23, 0.23, 0.57 * scale, Marsh.trunk)
            // Three offset masses give each conifer a stepped, printed silhouette.
            box(x, y, 0.35 * scale, 0.90 * scale, 0.80 * scale, 0.40 * scale, leaf)
            box(x - 0.035, y + 0.015, 0.75 * scale, 0.68 * scale, 0.60 * scale, 0.36 * scale, leaf)
            box(x - 0.05, y + 0.025, 1.11 * scale, 0.40 * scale, 0.37 * scale, 0.30 * scale, Marsh.pineTip)
        }
    }

    func log(_ mover: TrailMover, row: Int) {
        let x = mover.x, y = Double(row), w = mover.length, left = x - w / 2
        patch(left + 0.05, y - 0.38, w + 0.09, 0.74, Marsh.waterShadow)
        box(x, y, 0.02, w, 0.62, 0.16, Marsh.bark)
        box(x, y + 0.015, 0.18, w - 0.07, 0.47, 0.07, Marsh.bark)
        side(left + w + 0.002, y - 0.21, 0.045, 0.42, 0.105, Marsh.wood)
        side(left + w + 0.003, y - 0.07, 0.07, 0.14, 0.045, Marsh.grain)
        patch(left + 0.17, y - 0.12, w * 0.47, 0.048, Marsh.grain, z: 0.251)
        patch(x + 0.08, y + 0.095, w * 0.35, 0.035, Marsh.wood, z: 0.251)
        front(left + w * 0.22, y - 0.312, 0.085, w * 0.40, 0.031, Marsh.grain)
        if mover.id.isMultiple(of: 2) {
            patch(x - 0.18, y + 0.03, 0.27, 0.14, Marsh.grassShade, z: 0.252)
            patch(x + 0.07, y - 0.03, 0.13, 0.08, Marsh.grassLight, z: 0.252)
        }
        patch(left + 0.08, y - 0.405, 0.25, 0.029, Marsh.wave)
    }

    func car(_ mover: TrailMover, row: Int, right: Bool) {
        let x = mover.x, y = Double(row), w = mover.length
        let left = x - w / 2, sign = right ? 1.0 : -1.0
        let paint = Marsh.cars[Int(noise(mover.id, row) % 4)]
        patch(left + 0.05, y - 0.39, w + 0.10, 0.79, Marsh.softShadow)
        // The wheel faces peek through below the painted sill.
        for station in [-0.30, 0.30] {
            let wheel = x + w * station
            box(wheel, y - 0.25, 0.01, 0.265, 0.215, 0.245, Marsh.tires)
            front(wheel - 0.054, y - 0.359, 0.065, 0.108, 0.095, Marsh.hub)
        }
        box(x, y, 0.17, w, 0.63, 0.245, paint)
        let cabin = x - sign * w * 0.065
        box(cabin, y + 0.005, 0.415, w * 0.53, 0.51, 0.215, Marsh.glass)
        box(cabin - sign * 0.018, y + 0.005, 0.63, w * 0.50, 0.51, 0.055, paint)
        front(cabin - w * 0.025, y - 0.253, 0.414, 0.052, 0.216, paint.front)
        front(cabin - w * 0.18, y - 0.253, 0.56, w * 0.09, 0.028, Marsh.wave)
        let nose = right ? left + w - 0.13 : left + 0.015
        let tail = right ? left + 0.014 : left + w - 0.12
        front(nose, y - 0.317, 0.275, 0.105, 0.065, Marsh.headlight)
        front(tail, y - 0.317, 0.255, 0.10, 0.06, Marsh.taillight)
        let lamp = right ? Marsh.headlight : Marsh.taillight
        side(left + w + 0.002, y - 0.245, 0.28, 0.105, 0.07, lamp)
        side(left + w + 0.002, y + 0.14, 0.28, 0.105, 0.07, lamp)
    }

    func frog() {
        let x = game.playerX, y = game.playerY
        let row = Int(y.rounded())
        let onLog = game.lane(at: row).kind == .river && game.death != .water
        let deck = onLog ? 0.245 * max(0, 1 - abs(y - Double(row)) * 1.6) : 0
        let z = game.hopHeight + deck + 0.015
        let stretch = min(game.hopHeight * 0.32, 0.11)
        let shadowWidth = 0.78 - stretch
        patch(x - shadowWidth * 0.46, y - 0.31, shadowWidth, 0.58, Marsh.softShadow)

        var turn = 0.0
        var look = 0.0
        switch game.facing {
        case .left: turn = -1
        case .right: turn = 1
        case .forward: look = 1
        case .back: look = -1
        }

        let hx = x + turn * 0.12, hy = y + look * 0.085
        for foot in [-1.0, 1.0] {
            box(x + foot * 0.27, y - 0.10 - stretch, z, 0.22, 0.48, 0.12, Marsh.foot)
            box(x + foot * 0.27, y - 0.02, z + 0.095, 0.18, 0.28, 0.17, Marsh.frog)
        }
        box(x, y, z + 0.085, 0.58, 0.46, 0.28 + stretch, Marsh.frog)
        let collar = z + 0.32 + stretch
        box(hx, hy, collar, 0.62, 0.45, 0.09, Marsh.scarf)
        box(hx - 0.28, hy - 0.14, collar - 0.10, 0.12, 0.15, 0.13, Marsh.scarf)
        box(hx, hy, collar + 0.08, 0.68, 0.54, 0.205, Marsh.frogHead)
        front(hx - 0.065 + turn * 0.07, hy - 0.272, collar + 0.13, 0.14, 0.028, Marsh.grassDeep)
        for eye in [-1.0, 1.0] {
            let eyeX = hx + eye * 0.197
            box(eyeX, hy + 0.05, collar + 0.27, 0.205, 0.23, 0.17, Marsh.frog)
            front(eyeX - 0.10, hy - 0.068, collar + 0.28, 0.20, 0.155, Marsh.eye.front)
            front(eyeX - 0.041 + turn * 0.035, hy - 0.07, collar + 0.292, 0.088, 0.105, Marsh.pupil)
        }
    }
}
