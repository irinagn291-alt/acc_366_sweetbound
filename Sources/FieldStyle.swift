import SwiftUI

enum Field {
    static let ink = Color(red: 0.066, green: 0.133, blue: 0.111)
    static let panel = Color(red: 0.096, green: 0.181, blue: 0.145)
    static let paper = Color(red: 0.944, green: 0.946, blue: 0.846)
    static let amber = Color(red: 1.0, green: 0.80, blue: 0.38)
    static let lime = Color(red: 0.801, green: 0.964, blue: 0.366)
    static let muted = Color(red: 0.690, green: 0.766, blue: 0.628)
}

struct FieldLabel: View {
    let title: String
    var size: CGFloat = 11

    init(_ title: String, size: CGFloat = 11) {
        self.title = title
        self.size = size
    }

    var body: some View {
        Text(title)
            .font(.system(size: size, weight: .bold, design: .monospaced))
            .tracking(size * 0.095)
    }
}

struct MossWordmark: View {
    // Each row is a five-bit scanline of the hand-drawn cartridge lettering.
    private let letters = [
        [17, 27, 31, 21, 17, 17, 17], [14, 27, 27, 27, 27, 27, 14],
        [15, 24, 24, 14, 3, 3, 30], [15, 24, 24, 14, 3, 3, 30],
        [30, 27, 27, 30, 27, 27, 30], [14, 27, 27, 27, 27, 27, 14],
        [27, 27, 27, 27, 27, 27, 14], [19, 27, 31, 31, 27, 27, 25],
        [28, 30, 27, 27, 27, 30, 28]
    ]

    var body: some View {
        Canvas { context, size in
            let unit = min(size.width / 53, size.height / 7.5)
            var path = Path()
            for (i, letter) in letters.enumerated() {
                for (y, row) in letter.enumerated() {
                    for x in 0..<5 where row & (16 >> x) != 0 {
                        path.addRect(CGRect(x: CGFloat(i * 6 + x) * unit, y: CGFloat(y) * unit,
                                            width: unit + 0.15, height: unit + 0.15))
                    }
                }
            }
            var shadow = context
            shadow.translateBy(x: 0, y: unit * 0.52)
            shadow.fill(path, with: .color(Field.ink.opacity(0.23)))
            context.fill(path, with: .color(Field.ink))
        }
        .aspectRatio(53 / 7.5, contentMode: .fit)
        .accessibilityLabel("Sweetbound")
    }
}

struct TicketEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let count = max(1, Int(rect.width / 13))
        let tooth = rect.width / CGFloat(count)
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        for i in 0..<count {
            path.addLine(to: CGPoint(x: (CGFloat(i) + 0.5) * tooth, y: 0))
            path.addLine(to: CGPoint(x: CGFloat(i + 1) * tooth, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}

struct TrailButton: View {
    let title: String
    var symbol = "arrow.up.right"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 21, weight: .heavy, design: .rounded))
                Spacer()
                Image(systemName: symbol).font(.system(size: 19, weight: .black))
            }
            .foregroundStyle(Field.ink)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 51)
            .background(Field.lime, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}
