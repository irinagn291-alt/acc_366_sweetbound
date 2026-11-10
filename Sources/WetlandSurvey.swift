struct WetlandSurvey {
    static let finds = ["Heron feather", "Beaver tracks", "Dragonfly over water"]
    let day: TrailDay
    private var visited: Set<Int> = []

    var count: Int { visited.count }
    var complete: Bool { count == Self.finds.count }
    var latestFind: String? { count == 0 ? nil : Self.finds[count - 1] }

    init(day: TrailDay) { self.day = day }

    // A sign always lies on open grass. Later banks offer another chance to find one.
    func signColumn(row: Int, lane: TrailLane) -> Int? {
        guard !complete, row > 0, row % 3 == 1, lane.kind == .grass, !visited.contains(row) else { return nil }
        if row == 1 { return 0 }
        let clear = (-3...3).filter { !lane.blocked.contains($0) }
        let index = (day.seed &+ UInt64(row) &* 2_654_435_761) % UInt64(clear.count)
        return clear[Int(index)]
    }

    mutating func observe(column: Int, row: Int, lane: TrailLane) {
        if signColumn(row: row, lane: lane) == column { visited.insert(row) }
    }
}
