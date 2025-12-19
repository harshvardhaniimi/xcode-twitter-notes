import Foundation
import Speech
import AVFoundation

class SpeechService {
    static let shared = SpeechService()

    private init() {}

    /// Transcribe audio data to text using Speech framework
    /// This uses on-device speech recognition which doesn't require internet
    func transcribe(audioData: Data) async -> String? {
        // Request authorization
        let authorized = await requestAuthorization()
        guard authorized else { return nil }

        // Write audio data to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_audio_\(UUID().uuidString).m4a")

        do {
            try audioData.write(to: tempURL)
        } catch {
            print("Failed to write temp audio file: \(error)")
            return nil
        }

        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        return await withCheckedContinuation { continuation in
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

            guard let recognizer = recognizer, recognizer.isAvailable else {
                continuation.resume(returning: nil)
                return
            }

            let request = SFSpeechURLRecognitionRequest(url: tempURL)
            request.shouldReportPartialResults = false

            // Use on-device recognition if available (iOS 13+)
            if #available(iOS 13, *) {
                request.requiresOnDeviceRecognition = false // Set to true to force on-device only
            }

            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    print("Speech recognition error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                if let result = result, result.isFinal {
                    let transcription = result.bestTranscription.formattedString
                    continuation.resume(returning: transcription.isEmpty ? nil : transcription)
                }
            }
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
