//
//  ContentView.swift
//  Transcription Keeper
//
//  Created by Michael Fluharty on 11/27/25.
//

import SwiftUI

struct ContentView: View {
    @State private var recorder = SmartAudioRecorder()
    @State private var hasPermission = false
    @State private var showingPermissionAlert = false

    var body: some View {
        VStack(spacing: 30) {
            // Title
            Text("Transcription Keeper")
                .font(.largeTitle)
                .fontWeight(.bold)

            Spacer()

            // Level Meter
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
                    }
                }
                .frame(height: 20)
            }
            .padding(.horizontal, 40)

            // Duration
            if recorder.isRecording {
                Text(formatDuration(recorder.recordingDuration))
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundStyle(.red)
            }

            Spacer()

            // Record Button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? Color.red : Color.red.opacity(0.8))
                        .frame(width: 80, height: 80)

                    if recorder.isRecording {
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

            Text(recorder.isRecording ? "Tap to Stop" : "Tap to Record")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // Error display
            if let error = recorder.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
        .padding()
        .task {
            hasPermission = await recorder.requestPermission()
            if !hasPermission {
                showingPermissionAlert = true
            }
        }
        .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
            Button("OK") { }
        } message: {
            Text("Please enable microphone access in Settings to record audio.")
        }
    }

    // MARK: - Helpers

    private var levelColor: Color {
        if recorder.currentLevel > 0.8 {
            return .red
        } else if recorder.currentLevel > 0.5 {
            return .orange
        } else {
            return .green
        }
    }

    private func toggleRecording() {
        if recorder.isRecording {
            if let url = recorder.stopRecording() {
                print("Recording saved to: \(url)")
                // TODO: Pass to transcription service
            }
        } else {
            recorder.startRecording()
        }
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
