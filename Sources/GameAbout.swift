import SwiftUI

struct GameAbout: View {
    @Environment(\.dismiss) private var dismiss
    private static let links: [String: String] = {
        guard let url = Bundle.main.url(forResource: "StoreLinks", withExtension: "plist"),
              let data = try? Data(contentsOf: url) else { return [:] }
        return (try? PropertyListDecoder().decode([String: String].self, from: data)) ?? [:]
    }()
    private static let policy = Bundle.main.url(forResource: "Sweetbound-privacy", withExtension: "txt")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Image("FrogCrest").resizable().scaledToFit().frame(width: 68, height: 64)
                        .accessibilityHidden(true)
                    Text("Sweetbound")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .accessibilityAddTraits(.isHeader)
                    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                        Text("Version \(version)").font(.subheadline.monospaced())
                    }
                    Text("An arcade game about a frog crossing busy roads and rivers. Play crossings and daily expeditions offline.")
                        .font(.body)
                    Divider()
                    NavigationLink {
                        ScrollView {
                            Text(verbatim: Self.policy ?? "The privacy policy could not be loaded.")
                                .font(.body)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("aboutPrivacyText")
                                .textSelection(.enabled)
                                .padding(20)
                        }
                        .background(Field.paper.ignoresSafeArea())
                        .foregroundStyle(Field.ink)
                        .navigationTitle("Privacy")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { closeButton }
                    } label: {
                        HStack(spacing: 12) {
                            Label("Privacy policy", systemImage: "hand.raised.fill")
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").accessibilityHidden(true)
                        }
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("aboutPrivacy")
                    if let privacyURL = Self.httpsLink("PrivacyURL") {
                        Link(destination: privacyURL) {
                            Label("Privacy policy online", systemImage: "safari")
                                .frame(minHeight: 44)
                        }
                    }
                    if let supportURL = Self.httpsLink("SupportURL") {
                        Link(destination: supportURL) {
                            Label("Contact support", systemImage: "questionmark.circle")
                                .frame(minHeight: 44)
                        }
                    }
                }
                .frame(maxWidth: 570, alignment: .leading)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .foregroundStyle(Field.ink)
            .background(Field.paper.ignoresSafeArea())
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { closeButton }
        }
        .tint(Field.ink)
        .preferredColorScheme(.light)
        .presentationDragIndicator(.visible)
    }

    @ToolbarContentBuilder private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Close") { dismiss() }
                .accessibilityIdentifier("aboutClose")
        }
    }

    private static func httpsLink(_ key: String) -> URL? {
        guard let raw = links[key], let url = URL(string: raw),
              url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}
