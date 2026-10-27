//
//  TranscriptionService.swift
//  Transcription Keeper
//
//  Created by Michael Fluharty on 11/27/25.
//

import Foundation
import Speech
import AVFoundation
import BackgroundTasks

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

    /// How far through the recording the transcriber has heard, 0…1, and the recording's length in seconds.
    // REM  HIS REPORT, 2026-10-27: testers on cell at a doctor's office "didnt look obvious it was transcribing after
    // REM  the people pressed stop", and they "had to see the doctor". So progress is shown big (ContentView's
    // REM  transcribingPanel) and the work carries on with the phone locked or another app open (the background task below).
    var progress: Double = 0
    var audioLength: TimeInterval = 0

    /// The system's continued-processing task — keeps transcribing with the app in the background or the phone
    /// locked, and shows its own progress on the Lock Screen. Nil when the system declined it; transcribing still works
    /// in the foreground either way.
    private var backgroundTask: BGContinuedProcessingTask?

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
        progress = 0
        audioLength = (try? await AVURLAsset(url: audioURL).load(.duration).seconds).flatMap { $0.isFinite ? $0 : nil } ?? 0
        beginBackgroundTask()

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition not available"
            isTranscribing = false
            endBackgroundTask(success: false)
            return
        }

        do {
            statusMessage = "Transcribing..."

            // Create recognition request from audio file
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            // Partial results carry the timings heard so far — that is the progress bar.
            request.shouldReportPartialResults = true

            // Perform recognition
            let result = try await recognizer.recognitionTask(with: request) { [weak self] partial in
                guard let self, self.audioLength > 0, let last = partial.bestTranscription.segments.last else { return }
                self.setProgress(min(1, (last.timestamp + last.duration) / self.audioLength))
            }

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
            setProgress(1)
            endBackgroundTask(success: true)

        } catch {
            errorMessage = "Transcription failed: \(error.localizedDescription)"
            statusMessage = ""
            endBackgroundTask(success: false)
        }

        isTranscribing = false
    }

    private func setProgress(_ value: Double) {
        progress = value
        backgroundTask?.progress.completedUnitCount = Int64(value * 100)
    }

    // MARK: - Keep going in the background (iOS 26 continued processing)

    private static let taskPrefix = "com.NightGard.Transcription-Keeper.transcribe"

    /// Asks the system to let this transcription finish with the app in the background. Registered just before it is
    /// submitted — continued-processing tasks are exempt from register-at-launch (BGTaskScheduler.h).
    private func beginBackgroundTask() {
        let identifier = "\(Self.taskPrefix).\(UUID().uuidString.prefix(8))"
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { task in
            guard let task = task as? BGContinuedProcessingTask else { task.setTaskCompleted(success: false); return }
            MainActor.assumeIsolated {
                task.progress.totalUnitCount = 100
                task.progress.completedUnitCount = Int64(self.progress * 100)
                task.expirationHandler = { task.setTaskCompleted(success: false) }
                if self.isTranscribing { self.backgroundTask = task } else { task.setTaskCompleted(success: self.errorMessage == nil) }
            }
        }
        guard registered else { return }
        let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: "Transcribing",
                                                       subtitle: "Your recording is being turned into text.")
        request.strategy = .fail
        try? BGTaskScheduler.shared.submit(request)
    }

    private func endBackgroundTask(success: Bool) {
        backgroundTask?.setTaskCompleted(success: success)
        backgroundTask = nil
    }
}

// MARK: - SFSpeechRecognizer Extension

extension SFSpeechRecognizer {
    /// Async wrapper for recognition task
    func recognitionTask(with request: SFSpeechRecognitionRequest,
                         partial: @escaping @MainActor (SFSpeechRecognitionResult) -> Void = { _ in }) async throws -> SFSpeechRecognitionResult {
        try await withCheckedThrowingContinuation { continuation in
            var finished = false
            recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let error = error {
                    finished = true
                    continuation.resume(throwing: error)
                } else if let result = result, result.isFinal {
                    finished = true
                    continuation.resume(returning: result)
                } else if let result {
                    Task { @MainActor in partial(result) }
                }
            }
        }
    }
}
