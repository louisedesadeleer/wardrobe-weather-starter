import Foundation
import Observation
import Speech
import AVFoundation
@MainActor @Observable final class SpeechService {
    var transcript = ""
    var isListening = false
    var error: String?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var generation = UUID()
    private var tapInstalled = false
    func start() async {
        stop(); error = nil; transcript = ""
        let session = UUID(); generation = session
        let speech = await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
        let microphone = await withCheckedContinuation { continuation in AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) } }
        guard generation == session else { return }
        guard speech == .authorized, microphone else { error = "Allow microphone and speech recognition in Settings, or use the weather buttons."; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB")), recognizer.isAvailable else { error = "Speech recognition is unavailable. Please use the buttons."; return }
        do {
            let audio = AVAudioSession.sharedInstance(); try audio.setCategory(.record, mode: .measurement, options: .duckOthers); try audio.setActive(true)
            let request = SFSpeechAudioBufferRecognitionRequest(); request.shouldReportPartialResults = true; self.request = request
            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in request.append(buffer) }; tapInstalled = true
            engine.prepare(); try engine.start(); isListening = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self, self.generation == session else { return }
                    if let result { self.transcript = result.bestTranscription.formattedString }
                    if error != nil || result?.isFinal == true { self.stop() }
                }
            }
        } catch { self.error = error.localizedDescription; stop() }
    }
    func stop() {
        generation = UUID(); engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        request?.endAudio(); task?.cancel(); task = nil; request = nil; isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
