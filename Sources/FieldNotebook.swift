import SwiftUI

enum NotebookTab: String, CaseIterable, Identifiable {
    case guide, journal

    var id: Self { self }
    var title: String { self == .guide ? "How to play" : "My journal" }
}

struct FieldNotebook: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var tab: NotebookTab

    let journal: TrailJournal
    let best: Int
    let onPractice: () -> Void

    init(initialTab: NotebookTab, journal: TrailJournal, best: Int, onPractice: @escaping () -> Void) {
        _tab = State(initialValue: initialTab)
        self.journal = journal
        self.best = best
        self.onPractice = onPractice
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image("FrogCrest").resizable().scaledToFit().frame(width: 34, height: 32)
                    .accessibilityHidden(true)
                Text("Field notebook")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline.bold()).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close notebook")
                .accessibilityIdentifier("notebookClose")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    tabBar
                    if tab == .guide { guide } else { records }
                }
                .frame(maxWidth: 570)
                .padding(.horizontal, 20).padding(.vertical, 13)
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Field.ink)
        .background(Field.paper.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .presentationBackground(Field.paper)
    }

    private var tabBar: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 3)) : AnyLayout(HStackLayout(spacing: 3))
        return layout {
            ForEach(NotebookTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    Text(item.title)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(tab == item ? Field.paper : Field.ink)
                        .background(tab == item ? Field.ink : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                }
                .accessibilityAddTraits(tab == item ? .isSelected : [])
                .accessibilityIdentifier(item == .guide ? "guideTab" : "journalTab")
            }
        }
        .padding(3)
        .background(Field.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder private var guide: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("How to score")
            Text("Guide the frog as far as you can. Your first hop onto each new row earns one point. You can move back and choose another path.")
                .font(.body)
            Button(action: onPractice) {
                Label("Start practice", systemImage: "play.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 45)
                    .foregroundStyle(Field.ink)
                    .background(Field.lime, in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(.top, 3)
            .accessibilityIdentifier("startPractice")
        }
        .padding(16)
        .foregroundStyle(Field.paper)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Field.panel, in: RoundedRectangle(cornerRadius: 10))

        VStack(alignment: .leading, spacing: 12) {
            heading("On the trail")
            guideRow(.hopping, title: "Hop",
                     tip: "Tap the field to hop forward. Swipe up, down, left or right to hop in that direction. You can also use the arrow buttons below.")
            rule
            guideRow(.road, title: "Road",
                     tip: "Wait on the grass for a gap between cars. Check the traffic direction before crossing the next lane.")
            rule
            guideRow(.river, title: "River",
                     tip: "Hop onto a log when it lines up with you. It will carry you downstream. Jump to another log or the bank before you drift off the edge.")
            rule
            guideRow(.survey, title: "Daily expedition",
                     tip: "Collect three amber signs on grassy banks in one crossing. Hop onto a sign's tile to collect it. Missed one? There are more ahead.")
        }
    }

    @ViewBuilder private var records: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Personal best")
                .font(.system(.headline, design: .rounded, weight: .bold))
            Text(best.formatted())
                .font(.system(.largeTitle, design: .monospaced, weight: .black))
                .foregroundStyle(Field.lime)
            Text("Best distance in rows")
                .font(.subheadline)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Field.paper)
        .background(Field.panel, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Personal best distance in rows")
        .accessibilityValue(Text(best.formatted()))

        VStack(alignment: .leading, spacing: 10) {
            heading("Crossings")
            metric("Completed runs", value: journal.completedRuns.formatted())
            rule
            metric("Total rows crossed", value: journal.totalRows.formatted())
            rule
            metric("Today's expedition best, in rows",
                   value: journal.dailyBest(for: TrailDay())?.formatted() ?? "None yet")
            rule
            metric("Successful expedition days", value: journal.completedSurveys.formatted())
            if journal.completedRuns == 0 {
                Text("Finish your first crossing to record a result.")
                    .font(.footnote).foregroundStyle(Field.ink.opacity(0.75))
            }
        }

        VStack(alignment: .leading, spacing: 13) {
            heading("Observations")
            Text("In your notebook: \(journal.discoveredFindCount) of \(WetlandSurvey.finds.count)")
                .font(.subheadline.monospacedDigit())
            ForEach(WetlandSurvey.finds.indices, id: \.self) { index in
                let recorded = index < journal.discoveredFindCount
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: recorded ? "checkmark.seal.fill" : "circle.dashed")
                        .font(.headline)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(WetlandSurvey.finds[index])
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        Text(recorded ? fieldNote(index) : "Not found yet")
                            .font(.subheadline)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(recorded ? "fieldFind\(index)" : "undiscoveredFind\(index)")
            }
        }

        VStack(alignment: .leading, spacing: 13) {
            heading("Badges")
            ForEach(journal.milestones(best: best)) { milestone in
                badge(milestone)
            }
        }
        .padding(.top, 3)
    }

    private func fieldNote(_ index: Int) -> String {
        switch index {
        case 0: "A white feather caught on a stem by the water."
        case 1: "A trail of footprints crosses the shallows and ends at the water's edge."
        case 2: "Transparent wings shimmered above the dark channel."
        default: "A discovery recorded on an expedition."
        }
    }

    private var rule: some View {
        Rectangle().fill(Field.ink.opacity(0.2)).frame(height: 1).accessibilityHidden(true)
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(.system(.title2, design: .rounded, weight: .heavy))
            .accessibilityAddTraits(.isHeader)
    }

    private func guideRow(_ emblem: FieldEmblem.Kind, title: String, tip: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if !typeSize.isAccessibilitySize {
                FieldEmblem(kind: emblem).frame(width: 54, height: 49).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(.headline, design: .rounded, weight: .bold))
                Text(tip).font(.subheadline)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func metric(_ label: String, value: String) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 3))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 10))
        return layout {
            Text(label).font(.body)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 4) }
            Text(value).font(.system(.headline, design: .monospaced, weight: .bold))
        }
        .accessibilityElement(children: .combine)
    }

    private func badge(_ item: TrailMilestone) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if !typeSize.isAccessibilitySize {
                Image(systemName: item.symbol)
                    .font(.title3.bold())
                    .frame(width: 42, height: 42)
                    .foregroundStyle(item.unlocked ? Field.lime : Field.ink)
                    .background(item.unlocked ? Field.ink : Field.ink.opacity(0.09),
                                in: RoundedRectangle(cornerRadius: 7))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(item.title).font(.system(.headline, design: .rounded, weight: .bold))
                Text(item.detail).font(.subheadline)
                ProgressView(value: Double(item.progress), total: Double(item.goal))
                    .tint(Field.ink)
                Text(item.unlocked ? "Earned" : "\(item.progress) of \(item.goal)")
                    .font(.system(.footnote, design: .monospaced, weight: .semibold))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Field.ink.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.title). \(item.detail)"))
        .accessibilityValue(Text(item.unlocked ? "Badge earned" : "\(item.progress) of \(item.goal)"))
    }
}

// Small field-guide illustrations keep the frog, road and log recognizable at a glance.
private struct FieldEmblem: View {
    enum Kind { case hopping, road, river, survey }
    let kind: Kind

    var body: some View {
        ZStack {
            switch kind {
            case .hopping:
                Color(red: 0.62, green: 0.74, blue: 0.41)
                Image("FrogCrest").resizable().scaledToFit().padding(7)
            case .road:
                Color(red: 0.29, green: 0.33, blue: 0.36)
                VStack(spacing: 4) {
                    Image(systemName: "car.side.fill").font(.system(size: 25, weight: .bold))
                        .foregroundStyle(Color(red: 0.99, green: 0.75, blue: 0.38))
                    HStack(spacing: 4) {
                        ForEach(0..<3) { _ in Rectangle().frame(width: 10, height: 2) }
                    }.foregroundStyle(Field.paper)
                }
            case .river:
                Color(red: 0.22, green: 0.48, blue: 0.50)
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        Rectangle().fill(Color(red: 0.94, green: 0.76, blue: 0.48)).frame(width: 4)
                        Rectangle().fill(Color(red: 0.70, green: 0.50, blue: 0.32))
                    }
                    .frame(width: 37, height: 10).rotationEffect(.degrees(-8))
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Field.paper)
                }
            case .survey:
                Field.panel
                Image(systemName: "diamond.fill")
                    .font(.title2.bold())
                    .foregroundStyle(Color(red: 1, green: 0.78, blue: 0.34))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
