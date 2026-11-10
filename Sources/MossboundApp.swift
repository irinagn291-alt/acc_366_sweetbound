import SwiftUI

@main
struct MossboundApp: App {
    var body: some Scene {
        WindowGroup {
            CrossingView()
                .environment(\.locale, Locale(identifier: "en"))
                .preferredColorScheme(.dark)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
