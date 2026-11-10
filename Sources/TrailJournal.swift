import Foundation

struct TrailDay: Equatable {
    let id: String
    let seed: UInt64

    init(date: Date = .now, timeZone: TimeZone = .autoupdatingCurrent) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        id = String(format: "%04d-%02d-%02d", year, month, day)
        seed = UInt64(year * 10_000 + month * 100 + day)
    }
}

struct TrailMilestone: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let progress: Int
    let goal: Int

    var unlocked: Bool { progress >= goal }
}

struct TrailJournal {
    private struct DailyEntry: Codable {
        var best = 0
        var surveyCompleted = false
    }

    private struct Entries: Codable {
        var completedRuns = 0
        var totalRows = 0
        var days: [String: DailyEntry] = [:]
        var recentRunIDs: [UUID] = []
        var discoveredFinds: Int?

        var findCount: Int {
            let limit = WetlandSurvey.finds.count
            if let discoveredFinds { return min(limit, max(0, discoveredFinds)) }
            return days.values.contains(where: \.surveyCompleted) ? limit : 0
        }
    }

    private static let storageKey = "mossbound.journal.v1"
    private static let writeLock = NSLock()
    private let defaults: UserDefaults
    private var entries: Entries

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        entries = Self.load(from: defaults)
    }

    var completedRuns: Int { entries.completedRuns }
    var totalRows: Int { entries.totalRows }
    var completedSurveys: Int { entries.days.values.filter(\.surveyCompleted).count }
    var discoveredFindCount: Int { entries.findCount }

    mutating func discoverFinds(upTo count: Int) {
        updateEntries { entries in
            let found = min(count, WetlandSurvey.finds.count)
            guard found > entries.findCount else { return false }
            entries.discoveredFinds = found
            return true
        }
    }

    func dailyBest(for day: TrailDay) -> Int? {
        entries.days[day.id]?.best
    }

    func surveyCompleted(for day: TrailDay) -> Bool {
        entries.days[day.id]?.surveyCompleted == true
    }

    // Use the day and run identifier captured at the start, even across midnight or a pause.
    mutating func record(runID: UUID, score: Int, day: TrailDay?, surveyCompleted: Bool = false) {
        updateEntries { entries in
            guard !entries.recentRunIDs.contains(runID) else { return false }
            let rows = max(0, score)
            entries.completedRuns += 1
            entries.totalRows += rows
            if let day {
                var daily = entries.days[day.id] ?? DailyEntry()
                daily.best = max(rows, daily.best)
                daily.surveyCompleted = daily.surveyCompleted || surveyCompleted
                entries.days[day.id] = daily
                if surveyCompleted { entries.discoveredFinds = WetlandSurvey.finds.count }
            }
            entries.recentRunIDs = Array(entries.recentRunIDs.suffix(15)) + [runID]
            return true
        }
    }

    func milestones(best: Int) -> [TrailMilestone] {
        [
            TrailMilestone(id: "meadow", title: "First clearing", detail: "Reach row 4 in a single crossing.",
                           symbol: "leaf.fill", progress: min(best, 4), goal: 4),
            TrailMilestone(id: "river", title: "Across the river", detail: "Reach the bank beyond the first river at row 7.",
                           symbol: "water.waves", progress: min(best, 7), goal: 7),
            TrailMilestone(id: "daily", title: "Field scout", detail: "Collect three signs in one daily expedition.",
                           symbol: "binoculars.fill", progress: min(completedSurveys, 1), goal: 1),
            TrailMilestone(id: "distance", title: "Distant trails", detail: "Cross a total of 60 rows in completed runs.",
                           symbol: "signpost.right.fill", progress: min(totalRows, 60), goal: 60)
        ]
    }

    private mutating func updateEntries(_ change: (inout Entries) -> Bool) {
        // A collection and a finished run in different windows share the same saved journal.
        Self.writeLock.lock()
        defer { Self.writeLock.unlock() }
        entries = Self.load(from: defaults)
        guard change(&entries), let data = try? PropertyListEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> Entries {
        guard let data = defaults.data(forKey: storageKey),
              let saved = try? PropertyListDecoder().decode(Entries.self, from: data) else { return Entries() }
        return saved
    }
}
