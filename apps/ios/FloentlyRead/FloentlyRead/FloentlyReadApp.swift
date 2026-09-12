import SwiftUI
import FloentlyShared

@main
struct FloentlyReadApp: App {
    @StateObject private var browserRouter = ReadBrowserRouter()

    var body: some Scene {
        WindowGroup {
            ReadRootView()
                .environmentObject(browserRouter)
                .onOpenURL { incomingURL in
                    browserRouter.openIncomingURL(incomingURL)
                }
        }
    }
}

@MainActor
final class ReadBrowserRouter: ObservableObject {
    @Published var browserURL: URL?
    @Published var isBrowserPresented = false

    func openBrowser(_ url: URL? = nil) {
        browserURL = url
        isBrowserPresented = true
    }

    func openIncomingURL(_ incomingURL: URL) {
        guard let resolved = ReadBrowserController.resolveIncomingURL(incomingURL) else { return }
        openBrowser(resolved)
    }
}

struct ReadRootView: View {
    @EnvironmentObject private var browserRouter: ReadBrowserRouter

    var body: some View {
        NavigationStack {
            ReadHomeView {
                browserRouter.openBrowser()
            }
            .navigationDestination(isPresented: $browserRouter.isBrowserPresented) {
                ReadBrowserView(initialURL: browserRouter.browserURL)
            }
        }
    }
}

struct ReadHomeView: View {
    let openBrowser: () -> Void

    var body: some View {
        FloentlyScreen(product: .read) {
            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                Text("Floently Read")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Listen to documents and live websites without replacing the page you are using.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.72))

                FloentlyCard(product: .read) {
                    Text("Browse & listen")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Open the real website inside Read. Sign in, move between lessons and keep the same live browsing session while Read stays available.")
                        .foregroundStyle(.white.opacity(0.72))
                }

                FloentlyPrimaryButton("Open Reading Browser", product: .read, action: openBrowser)

                Spacer()
            }
        }
    }
}
