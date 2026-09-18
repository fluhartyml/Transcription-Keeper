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

    /// The recognised words WITH their timings, kept so speaker separation has
    /// something to attach names to. `formattedString` throws the timings away, and
    /// the diarizer answers "who spoke between 4.1s and 7.8s" — without these the two
    /// halves cannot be joined at all.
    var tokens: [Token] = []

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
        tokens = []
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

            // Keep the timed segments BEFORE flattening to a string. Each
            // SFTranscriptionSegment carries its own timestamp and duration; the
            // formatted string carries neither.
            tokens = result.bestTranscription.segments.map {
                Token(text: $0.substring,
                      start: $0.timestamp,
                      end: $0.timestamp + $0.duration)
            }

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
