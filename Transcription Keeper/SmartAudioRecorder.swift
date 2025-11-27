//
//  SmartAudioRecorder.swift
//  Transcription Keeper
//
//  Created by Michael Fluharty on 11/27/25.
//

import AVFoundation
import Foundation

/// Smart audio recorder with level metering for threshold-based recording.
/// Monitors audio levels in real-time to support voice activity detection.
/// Only records when audio exceeds user-set threshold - skips silence automatically.
@MainActor
@Observable
class SmartAudioRecorder: NSObject {

    // MARK: - Published State

    /// Whether a recording session is active (listening for audio)
    var isSessionActive = false

    /// Whether currently capturing audio (above threshold)
    var isCapturing = false

    /// Current audio level (0.0 to 1.0, normalized from dB)
    var currentLevel: Float = 0.0

    /// User-adjustable threshold (0.0 to 1.0) - audio below this is ignored
    var threshold: Float = 0.15

    /// URL of the last recorded audio file
    var recordingURL: URL?

    /// Error message if recording fails
    var errorMessage: String?

    /// Total session duration (listening time)
    var sessionDuration: TimeInterval = 0

    /// Actual captured audio duration (above threshold)
    var capturedDuration: TimeInterval = 0

    // MARK: - Legacy compatibility
    var isRecording: Bool { isSessionActive }
    var recordingDuration: TimeInterval { capturedDuration }

    // MARK: - Private Properties

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private var gracePeriodTimer: Timer?

    /// Grace period in seconds - keeps recording briefly after level drops
    private let gracePeriod: TimeInterval = 0.8

    // MARK: - Recording Settings

    /// Audio format settings optimized for speech transcription
    private var recordingSettings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }

    // MARK: - Public Methods

    /// Request microphone permission
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Start a recording session - listens for audio above threshold
    func startRecording() {
        errorMessage = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            errorMessage = "Failed to set up audio session: \(error.localizedDescription)"
            return
        }

        // Create unique filename with timestamp
        let filename = "TranscriptionKeeper-\(ISO8601DateFormatter().string(from: Date())).m4a"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        recordingURL = fileURL

        // Create and configure recorder
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: recordingSettings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.delegate = self

            // Prepare but don't start recording yet - wait for threshold
            audioRecorder?.prepareToRecord()

            isSessionActive = true
            isCapturing = false
            sessionDuration = 0
            capturedDuration = 0
            startMetering()
            startDurationTimer()
        } catch {
            errorMessage = "Failed to create recorder: \(error.localizedDescription)"
        }
    }

    /// Stop recording session and return the audio file URL
    func stopRecording() -> URL? {
        guard isSessionActive else { return nil }

        gracePeriodTimer?.invalidate()
        gracePeriodTimer = nil

        if isCapturing {
            audioRecorder?.stop()
        }

        isSessionActive = false
        isCapturing = false
        stopMetering()
        stopDurationTimer()

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }

        // Only return URL if we actually captured something
        if capturedDuration > 0 {
            return recordingURL
        } else {
            // Clean up empty file
            if let url = recordingURL {
                try? FileManager.default.removeItem(at: url)
            }
            return nil
        }
    }

    /// Start capturing (when audio exceeds threshold)
    private func startCapturing() {
        guard !isCapturing, isSessionActive else { return }

        gracePeriodTimer?.invalidate()
        gracePeriodTimer = nil

        if audioRecorder?.record() == true {
            isCapturing = true
        }
    }

    /// Stop capturing (when audio drops below threshold)
    private func stopCapturing() {
        guard isCapturing, isSessionActive else { return }

        // Use grace period to avoid choppy recordings
        gracePeriodTimer?.invalidate()
        gracePeriodTimer = Timer.scheduledTimer(withTimeInterval: gracePeriod, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isSessionActive, self.isCapturing else { return }
                // Check level again - maybe it came back up during grace period
                if self.currentLevel < self.threshold {
                    self.audioRecorder?.pause()
                    self.isCapturing = false
                }
            }
        }
    }

    /// Get current audio level in decibels (for threshold comparison)
    func getCurrentDecibelLevel() -> Float {
        guard let recorder = audioRecorder, isSessionActive else { return -160 }
        recorder.updateMeters()
        return recorder.averagePower(forChannel: 0)
    }

    // MARK: - Private Methods

    private func startMetering() {
        // Update levels 20 times per second for smooth UI
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLevel()
            }
        }
    }

    private func stopMetering() {
        levelTimer?.invalidate()
        levelTimer = nil
        currentLevel = 0
    }

    private func updateLevel() {
        guard let recorder = audioRecorder, isSessionActive else {
            currentLevel = 0
            return
        }

        recorder.updateMeters()
        let dB = recorder.averagePower(forChannel: 0)

        // Convert dB to normalized 0-1 range
        // Typical range: -160 dB (silence) to 0 dB (max)
        // We'll use -50 dB as practical silence threshold
        let minDB: Float = -50
        let maxDB: Float = 0
        let normalizedLevel = max(0, min(1, (dB - minDB) / (maxDB - minDB)))

        currentLevel = normalizedLevel

        // Threshold-based capture control
        if normalizedLevel >= threshold {
            if !isCapturing {
                startCapturing()
            } else {
                // Cancel any pending stop
                gracePeriodTimer?.invalidate()
                gracePeriodTimer = nil
            }
        } else if isCapturing {
            stopCapturing()
        }
    }

    private func startDurationTimer() {
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isSessionActive else { return }
                self.sessionDuration += 0.1
                if self.isCapturing {
                    self.capturedDuration += 0.1
                }
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }
}

// MARK: - AVAudioRecorderDelegate

extension SmartAudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                errorMessage = "Recording finished unsuccessfully"
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                errorMessage = "Encoding error: \(error.localizedDescription)"
            }
        }
    }
}
