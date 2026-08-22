import AVFoundation

@MainActor
final class SpeechCoach: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ step: WorkoutStep) {
        synthesizer.stopSpeaking(at: .immediate)
        let text = "现在是\(step.phase.rawValue)。\(step.name)，\(step.prescription)。注意，\(step.cue)"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }
}
