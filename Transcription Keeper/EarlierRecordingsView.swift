//
//  EarlierRecordingsView.swift
//  Transcription Keeper
//
//  Every take still on this phone, newest first — so one that never transcribed can be.
//
// REM  HIS REPORT, 2026-10-27: "i think i pressed stop and it looked like it wasnt doing anything so i pressed the red
// REM  button again and it started a new recording but the old recording never transcribed" — "is there a way to get a
// REM  previous transcript". Every take is saved as its own file (TranscriptionKeeper-<time>.m4a in the app's temporary
// REM  folder) BEFORE it is transcribed, and nothing removes it except Cancel. So the lost take is very likely still here;
// REM  this list is the way back to it. iOS may clear the temporary folder on its own, so the list can come up short.
// REM  The list cannot tell which takes were already transcribed — they were never marked — so it shows them all, by time.

import SwiftUI
import AVFoundation

struct EarlierRecording: Identifiable, Hashable {
    let url: URL
    let made: Date
    var id: URL { url }

    /// Every take on this phone, newest first.
    static func all() -> [EarlierRecording] {
        let folder = FileManager.default.temporaryDirectory
        let names = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return names
            .filter { $0.lastPathComponent.hasPrefix("TranscriptionKeeper-") && $0.pathExtension == "m4a" }
            .map { EarlierRecording(url: $0, made: (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) }
            .sorted { $0.made > $1.made }
    }
}

struct EarlierRecordingsView: View {
    /// Transcribes the chosen take on the main screen, the same way a new one is.
    let transcribe: (URL) -> Void
    @State private var recordings = EarlierRecording.all()
    @State private var lengths: [URL: TimeInterval] = [:]
    @State private var sharing: EarlierRecording?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if recordings.isEmpty {
                    Text("No earlier recordings are on this iPhone.")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                ForEach(recordings) { take in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(take.made.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 20, weight: .semibold))
                        if let length = lengths[take.url] {
                            Text(Duration.seconds(length).formatted(.time(pattern: .hourMinuteSecond)))
                                .font(.system(size: 18))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            Button {
                                dismiss()
                                transcribe(take.url)
                            } label: { Label("Transcribe", systemImage: "text.bubble") }
                                .buttonStyle(.borderedProminent)
                            Button { sharing = take } label: { Label("Share Audio", systemImage: "square.and.arrow.up") }
                                .buttonStyle(.bordered)
                        }
                        .font(.system(size: 18))
                    }
                    .padding(.vertical, 6)
                    .task {
                        if let length = try? await AVURLAsset(url: take.url).load(.duration).seconds, length.isFinite {
                            lengths[take.url] = length
                        }
                    }
                }
            }
            .navigationTitle("Earlier Recordings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $sharing) { take in ShareSheet(items: [take.url]) }
        }
    }
}
