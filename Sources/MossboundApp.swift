import SwiftUI

@main
struct MossboundApp: App {
    @StateObject private var launch = AppLaunch()

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG && targetEnvironment(simulator)
                if CaptureRoute.requested != nil {
                    nativeRoot
                } else {
                    normalRoot
                }
                #else
                normalRoot
                #endif
            }
        }
    }

    private var normalRoot: some View {
        Group {
            switch launch.mode {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .webContent:
                if let url = launch.contentURL { InAppBrowser(url: url) }
                else { nativeRoot }
            case .nativeInterface:
                nativeRoot
            }
        }
        .task { launch.start() }
    }

    private var nativeRoot: some View {
        CrossingView()
            .environment(\.locale, Locale(identifier: "en"))
            .preferredColorScheme(.dark)
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
    }
}
