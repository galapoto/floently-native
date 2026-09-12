import SwiftUI
import FloentlyShared

struct ReadBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controller = ReadBrowserController()
    @StateObject private var speech = ReadSpeechController()
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

            if controller.currentURL == nil {
                browserStart
            } else {
                ZStack(alignment: .bottom) {
                    ReadWebView(controller: controller)
                        .ignoresSafeArea(edges: .bottom)

                    readStrip
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }
        }
        .background(palette.background)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if let initialURL, controller.currentURL == nil {
                controller.open(url: initialURL)
            }
        }
        .onChange(of: controller.extractedText) { _, text in
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            speech.speak(text)
        }
        .onChange(of: controller.selectionText) { _, text in
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            speech.speak(text)
        }
        .onChange(of: controller.currentURL) { _, _ in
            speech.stop()
        }
        .onDisappear {
            speech.stop()
        }
    }

    private var browserToolbar: some View {
        HStack(spacing: 6) {
            browserButton(systemName: "chevron.left", enabled: true, label: "Back") {
                if controller.canGoBack {
                    controller.goBack()
                } else {
                    dismiss()
                }
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
                enabled: controller.currentURL != nil,
                label: controller.isLoading ? "Stop loading" : "Reload"
            ) {
                controller.isLoading ? controller.stopLoading() : controller.reload()
            }

            browserButton(systemName: "xmark.circle", enabled: true, label: "Close browser") {
                dismiss()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 56)
        .background(palette.surface)
    }

    private var browserStart: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "globe")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)

            Text("Browse the real website")
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.text)

            Text("Enter a course, article or website above. Read keeps the original page interactive and stays available while you navigate.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.muted)
                .frame(maxWidth: 420)

            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }

    private var readStrip: some View {
        HStack(spacing: 8) {
            Button {
                if speech.isSpeaking || speech.isPaused {
                    speech.togglePauseResume()
                } else {
                    controller.extractedText = ""
                    controller.readPage()
                }
            } label: {
                Label(
                    speech.isSpeaking ? "Pause" : speech.isPaused ? "Resume" : "Read page",
                    systemImage: speech.isSpeaking ? "pause.fill" : "play.fill"
                )
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(palette.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Reads the main visible lesson or article area without replacing the website")

            Button {
                controller.selectionText = ""
                controller.readSelection()
            } label: {
                Image(systemName: "selection.pin.in.out")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .frame(width: 44, height: 48)
                    .background(palette.elevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Read selected text")

            Button {
                speech.cycleSpeed()
            } label: {
                Text(speech.speedLabel)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(palette.text)
                    .frame(width: 44, height: 48)
                    .background(palette.elevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reading speed \(speech.speedLabel)")

            VStack(alignment: .leading, spacing: 2) {
                Text(speech.isSpeaking || speech.isPaused ? speech.status : controller.readingStatus)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(palette.text.opacity(0.82))
                    .lineLimit(1)
                if speech.isSpeaking || speech.isPaused {
                    Text(controller.pageTitle.isEmpty ? "Live page" : controller.pageTitle)
                        .font(.caption2)
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                }
            }
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
