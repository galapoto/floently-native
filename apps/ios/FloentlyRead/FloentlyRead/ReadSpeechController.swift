import AVFAudio
import AVFoundation
import Combine
import Foundation

@MainActor
final class ReadSpeechController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    @Published private(set) var isPaused = false
    @Published private(set) var status = "Ready"
    @Published private(set) var speedLabel = "1×"

    private let synthesizer = AVSpeechSynthesizer()
    private var sourceText = ""
    private var sourceLanguage = "en-US"
    private var speechRate: Float = 0.50

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: String? = nil) {
        let normalized = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            status = "No readable text is available yet."
            return
        }

        stop()
        sourceText = normalized
        sourceLanguage = normalizedLanguage(language)
        configureAudioSession()

        let utterance = AVSpeechUtterance(string: normalized)
        utterance.rate = speechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.05
        utterance.voice = bestVoice(for: sourceLanguage)

        isSpeaking = true
        isPaused = false
        status = "Reading"
        synthesizer.speak(utterance)
    }

    func togglePauseResume() {
        if isPaused {
            if synthesizer.continueSpeaking() {
                isPaused = false
                isSpeaking = true
                status = "Reading"
            }
            return
        }

        if synthesizer.isSpeaking, synthesizer.pauseSpeaking(at: .word) {
            isPaused = true
            isSpeaking = false
            status = "Paused"
        }
    }

    func restart() {
        guard !sourceText.isEmpty else { return }
        speak(sourceText, language: sourceLanguage)
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        isPaused = false
        status = "Ready"
    }

    func cycleSpeed() {
        switch speedLabel {
        case "0.8×":
            speedLabel = "1×"
            speechRate = 0.50
        case "1×":
            speedLabel = "1.2×"
            speechRate = 0.56
        case "1.2×":
            speedLabel = "1.5×"
            speechRate = 0.62
        default:
            speedLabel = "0.8×"
            speechRate = 0.44
        }

        if !sourceText.isEmpty, synthesizer.isSpeaking || synthesizer.isPaused {
            speak(sourceText, language: sourceLanguage)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        isPaused = false
        status = "Finished"
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        isPaused = false
        if status != "Reading" {
            status = "Ready"
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // AVSpeechSynthesizer can still speak with the app's existing audio session.
        }
    }

    private func normalizedLanguage(_ candidate: String?) -> String {
        let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty { return "en-US" }
        if value.count == 2 {
            let lower = value.lowercased()
            let locale = Locale(identifier: lower)
            if let region = locale.region?.identifier {
                return "\(lower)-\(region)"
            }
        }
        return value.replacingOccurrences(of: "_", with: "-")
    }

    private func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let requestedPrefix = language.split(separator: "-").first.map(String.init)?.lowercased() ?? "en"
        let matches = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language.lowercased() == language.lowercased()
                || $0.language.lowercased().hasPrefix("\(requestedPrefix)-")
        }

        return matches.max { lhs, rhs in
            lhs.quality.rawValue < rhs.quality.rawValue
        } ?? AVSpeechSynthesisVoice(language: language)
          ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}
