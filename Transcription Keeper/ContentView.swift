//
//  ContentView.swift
//  Transcription Keeper
//
//  Created by Michael Fluharty on 11/27/25.
//

import SwiftUI

struct ContentView: View {
    @State private var recorder = SmartAudioRecorder()
    @State private var transcriptionService = TranscriptionService()
    @State private var hasPermission = false
    @State private var showingPermissionAlert = false
    @State private var showingAbout = false

    // Results state
    @State private var lastRecordingURL: URL?
    @State private var showingResults = false
    @State private var showingShareText = false
    @State private var showingShareAudio = false

    var body: some View {
        VStack(spacing: 24) {
            // Title
            Image("KnightMicWaveform")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .cornerRadius(20)

            Text("Transcription Keeper")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Status indicator
            if recorder.isSessionActive {
                HStack(spacing: 8) {
                    Circle()
                        .fill(recorder.isCapturing ? Color.red : Color.orange)
                        .frame(width: 12, height: 12)
                    Text(recorder.isCapturing ? "Recording" : "Listening...")
                        .font(.headline)
                        .foregroundStyle(recorder.isCapturing ? .red : .orange)
                }
            } else if transcriptionService.isTranscribing {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(transcriptionService.statusMessage)
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
            }

            // Show results or recording UI
            if showingResults && !transcriptionService.isTranscribing {
                resultsView
            } else {
                recordingView
            }

            // Error display
            if let error = recorder.errorMessage ?? transcriptionService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
        .padding()
        .task {
            hasPermission = await recorder.requestPermission()
            let speechPermission = await transcriptionService.requestPermission()
            if hasPermission {
                recorder.startMonitoring()
            } else {
                showingPermissionAlert = true
            }
            if !speechPermission {
                transcriptionService.errorMessage = "Speech recognition permission required"
            }
        }
        .onDisappear {
            recorder.stopMonitoring()
        }
        .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
            Button("OK") { }
        } message: {
            Text("Please enable microphone access in Settings to record audio.")
        }
        .sheet(isPresented: $showingShareText) {
            ShareSheet(items: [transcriptionService.transcription])
        }
        .sheet(isPresented: $showingShareAudio) {
            if let url = lastRecordingURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showingAbout = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Level Meter with Threshold
            VStack(spacing: 8) {
                Text("Audio Level")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))

                        // Level indicator
                        RoundedRectangle(cornerRadius: 4)
                            .fill(levelColor)
                            .frame(width: geometry.size.width * CGFloat(recorder.currentLevel))

                        // Threshold line
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2)
                            .offset(x: geometry.size.width * CGFloat(recorder.threshold) - 1)
                    }
                }
                .frame(height: 24)

                // Threshold Slider
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Slider(value: $recorder.threshold, in: 0.05...0.8)
                        .tint(.orange)
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Text("Sensitivity Threshold: \(Int(recorder.threshold * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 30)

            // Duration display
            if recorder.isSessionActive {
                VStack(spacing: 4) {
                    // Captured time (main display)
                    Text(formatDuration(recorder.capturedDuration))
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundStyle(recorder.isCapturing ? .red : .primary)

                    // Session time (smaller)
                    Text("Session: \(formatDuration(recorder.sessionDuration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Record Button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(recorder.isSessionActive ? Color.red : Color.red.opacity(0.8))
                        .frame(width: 80, height: 80)

                    if recorder.isSessionActive {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 30, height: 30)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(transcriptionService.isTranscribing)

            Text(recorder.isSessionActive ? "Tap to Stop" : "Tap to Record")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 20) {
            // Transcription text
            VStack(alignment: .leading, spacing: 8) {
                Text("Transcription")
                    .font(.headline)

                ScrollView {
                    Text(transcriptionService.transcription)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal)

            // Share buttons
            HStack(spacing: 16) {
                Button(action: { showingShareText = true }) {
                    Label("Share Text", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button(action: { showingShareAudio = true }) {
                    Label("Share Audio", systemImage: "waveform")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.horizontal)

            // New recording button
            Button(action: startNewRecording) {
                Label("New Recording", systemImage: "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Helpers

    private var levelColor: Color {
        // Red when above threshold (capturing), green when below (not capturing)
        if recorder.currentLevel >= recorder.threshold {
            return .red  // Above threshold - capturing
        } else {
            return .green  // Below threshold - not capturing
        }
    }

    private func toggleRecording() {
        if recorder.isSessionActive {
            if let url = recorder.stopRecording() {
                print("Recording saved to: \(url)")
                print("Captured \(recorder.capturedDuration)s of \(recorder.sessionDuration)s session")
                lastRecordingURL = url

                // Start transcription
                Task {
                    await transcriptionService.transcribe(audioURL: url)
                    showingResults = true
                }
            } else {
                print("No audio captured")
                recorder.startMonitoring()
            }
        } else {
            showingResults = false
            recorder.startRecording()
        }
    }

    private func startNewRecording() {
        showingResults = false
        transcriptionService.transcription = ""
        transcriptionService.errorMessage = nil
        recorder.startMonitoring()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

#Preview {
    ContentView()
}
