//
//  TranscriptionService.swift
//  Transcription Keeper
//
//  Created by Michael Fluharty on 11/27/25.
//

import Foundation
import Speech

/// Service for transcribing audio files using SFSpeechRecognizer
@MainActor
@Observable
class TranscriptionService {

    // MARK: - Published State

    /// Whether transcription is in progress
    var isTranscribing = false

    /// The transcribed text result
    var transcription: String = ""

    /// Error message if transcription fails
    var errorMessage: String?

    /// Progress message during transcription
    var statusMessage: String = ""

    // MARK: - Private Properties

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)

    // MARK: - Public Methods

    /// Request speech recognition permission
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribe audio file at URL
    func transcribe(audioURL: URL) async {
        isTranscribing = true
        transcription = ""
        errorMessage = nil
        statusMessage = "Preparing transcription..."

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition not available"
            isTranscribing = false
            return
        }

        do {
            statusMessage = "Transcribing..."

            // Create recognition request from audio file
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false

            // Perform recognition
            let result = try await recognizer.recognitionTask(with: request)

            transcription = result.bestTranscription.formattedString
            if transcription.isEmpty {
                transcription = "(No speech detected)"
            }
            statusMessage = "Transcription complete"

        } catch {
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            statusMessage = ""
        }

        isTranscribing = false
    }
}

// MARK: - SFSpeechRecognizer Extension

extension SFSpeechRecognizer {
    /// Async wrapper for recognition task
    func recognitionTask(with request: SFSpeechRecognitionRequest) async throws -> SFSpeechRecognitionResult {
        try await withCheckedThrowingContinuation { continuation in
            recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result, result.isFinal {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}
