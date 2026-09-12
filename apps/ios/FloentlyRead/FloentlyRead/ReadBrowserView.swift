import SwiftUI
import FloentlyShared

struct ReadBrowserView: View {
    @StateObject private var controller = ReadBrowserController()
    let initialURL: URL?

    private let palette = FloentlyPalette.read

    var body: some View {
        VStack(spacing: 0) {
            browserToolbar

            if controller.isLoading {
                ProgressView(value: controller.estimatedProgress)
                    .progressViewStyle(.linear)
                    .tint(palette.accent)
            }

            ZStack(alignment: .bottom) {
                ReadWebView(controller: controller)
                    .ignoresSafeArea(edges: .bottom)

                readStrip
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
        .background(palette.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if let initialURL {
                controller.open(url: initialURL)
            } else if controller.currentURL == nil {
                controller.open("https://read.floently.com")
            }
        }
    }

    private var browserToolbar: some View {
        HStack(spacing: 6) {
            browserButton(systemName: "chevron.left", enabled: controller.canGoBack, label: "Back") {
                controller.goBack()
            }

            browserButton(systemName: "chevron.right", enabled: controller.canGoForward, label: "Forward") {
                controller.goForward()
            }

            TextField("Search or enter website", text: $controller.addressText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .onSubmit { controller.open(controller.addressText) }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(palette.elevated.opacity(0.92))
                .foregroundStyle(palette.text)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                )
                .accessibilityLabel("Website address")

            browserButton(
                systemName: controller.isLoading ? "xmark" : "arrow.clockwise",
                enabled: true,
                label: controller.isLoading ? "Stop loading" : "Reload"
            ) {
                controller.isLoading ? controller.stopLoading() : controller.reload()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 56)
        .background(palette.surface)
    }

    private var readStrip: some View {
        HStack(spacing: 8) {
            Button {
                controller.readPage()
            } label: {
                Label("Read page", systemImage: "play.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(palette.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Reads the main visible lesson or article area without replacing the website")

            Button {
                controller.readSelection()
            } label: {
                Image(systemName: "selection.pin.in.out")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .frame(width: 48, height: 48)
                    .background(palette.elevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Read selected text")

            Text(controller.readingStatus)
                .font(.footnote.weight(.medium))
                .foregroundStyle(palette.text.opacity(0.82))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private func browserButton(
        systemName: String,
        enabled: Bool,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(enabled ? palette.text : palette.muted.opacity(0.5))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
