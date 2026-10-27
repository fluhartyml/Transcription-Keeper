//
//  SavedDocuments.swift
//  Transcription Keeper
//
//  Documents are saved as they are built, and deleted — with their recordings — after the time the user picks.
//
// REM  HIS ASK, 2026-10-27: "can you save them and have them expire after a user set time? 24 hrs a week or month?" ·
// REM  named by date and time, not an ID — "is it or can it be date and time stamped?" → "Transcript 2026-10-27 4:10 PM",
// REM  local time. A document's clock runs from its LAST change, so one still being added to does not expire mid-report.
// REM  Its recordings move out of the temporary folder (which iOS may empty) into Application Support/Recordings, so a
// REM  saved document keeps its audio until it expires. Earlier Recordings lists both places.

import Foundation
import SwiftUI

struct SavedDocument: Codable, Identifiable, Hashable {
    var name: String
    var created: Date
    var changed: Date
    var paragraphs: [String]
    /// File names in TranscriptStore.recordings.
    var audio: [String]
    var id: String { name }
    var text: String { paragraphs.joined(separator: "\n\n") }
    var audioURLs: [URL] { audio.map { TranscriptStore.recordings.appendingPathComponent($0) } }
}

enum TranscriptStore {
    /// How long a document is kept after its last change, in days. 1, 7 or 30.
    static let lifetimeKey = "documentLifetimeDays"
    static let lifetimes: [(days: Int, label: String)] = [(1, "24 Hours"), (7, "1 Week"), (30, "1 Month")]

    private static var support: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
    static var recordings: URL { folder("Recordings") }
    private static var documents: URL { folder("Transcripts") }

    private static func folder(_ name: String) -> URL {
        let url = support.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// "Transcript 2026-10-27 4:10 PM" — local time, unique (a second document in the same minute gets its seconds).
    static func newName(at date: Date = .now) -> String {
        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        var name = "Transcript " + day.string(from: date) + " " + date.formatted(date: .omitted, time: .shortened)
        if FileManager.default.fileExists(atPath: file(name).path) {
            name += " " + date.formatted(.dateTime.second(.twoDigits)) + "s"
        }
        return name
    }

    private static func file(_ name: String) -> URL { documents.appendingPathComponent(name + ".json") }

    /// Moves a take out of the temporary folder so it lives as long as its document.
    static func keep(_ url: URL) -> URL {
        let target = recordings.appendingPathComponent(url.lastPathComponent)
        guard url.deletingLastPathComponent().standardizedFileURL != recordings.standardizedFileURL else { return url }
        do { try FileManager.default.moveItem(at: url, to: target); return target } catch { return url }
    }

    static func save(_ document: SavedDocument) {
        guard let data = try? JSONEncoder().encode(document) else { return }
        try? data.write(to: file(document.name), options: .atomic)
    }

    static func all() -> [SavedDocument] {
        let files = (try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(SavedDocument.self, from: Data(contentsOf: $0)) }
            .sorted { $0.changed > $1.changed }
    }

    static func delete(_ document: SavedDocument) {
        for url in document.audioURLs { try? FileManager.default.removeItem(at: url) }
        try? FileManager.default.removeItem(at: file(document.name))
    }

    /// Deletes every document — and its recordings — whose time is up. Run at launch and when the list opens.
    static func purgeExpired() {
        let stored = UserDefaults.standard.integer(forKey: lifetimeKey)
        let days = stored == 0 ? 7 : stored
        let cutoff = Date.now.addingTimeInterval(-Double(days) * 86_400)
        for document in all() where document.changed < cutoff { delete(document) }
    }

    static func expires(_ document: SavedDocument, days: Int) -> Date {
        document.changed.addingTimeInterval(Double(days) * 86_400)
    }
}

struct SavedDocumentsView: View {
    /// Opens a saved document as the current one, to read, share or add paragraphs to.
    let open: (SavedDocument) -> Void
    @AppStorage(TranscriptStore.lifetimeKey) private var days = 7
    @State private var documents: [SavedDocument] = []
    @State private var confirmDelete: SavedDocument?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Delete after", selection: $days) {
                        ForEach(TranscriptStore.lifetimes, id: \.days) { Text($0.label).tag($0.days) }
                    }
                    .font(.system(size: 18))
                } footer: {
                    Text("A document and its recordings are deleted this long after its last change.")
                        .font(.system(size: 18))
                }
                if documents.isEmpty {
                    Text("No saved documents.").font(.system(size: 18)).foregroundStyle(.secondary)
                }
                ForEach(documents) { document in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(document.name).font(.system(size: 20, weight: .semibold))
                        Text(document.paragraphs.first ?? "")
                            .font(.system(size: 18))
                            .lineLimit(2)
                            .foregroundStyle(.secondary)
                        Text("\(document.paragraphs.count) paragraph\(document.paragraphs.count == 1 ? "" : "s") · deleted \(TranscriptStore.expires(document, days: days).formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button { dismiss(); open(document) } label: { Label("Open", systemImage: "doc.text") }
                                .buttonStyle(.borderedProminent)
                            Button(role: .destructive) { confirmDelete = document } label: { Label("Delete", systemImage: "trash") }
                                .buttonStyle(.bordered)
                        }
                        .font(.system(size: 18))
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Saved Documents")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { TranscriptStore.purgeExpired(); documents = TranscriptStore.all() }
            .onChange(of: days) { TranscriptStore.purgeExpired(); documents = TranscriptStore.all() }
            .alert("Delete this document and its recordings?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
                Button("Delete", role: .destructive) {
                    if let confirmDelete { TranscriptStore.delete(confirmDelete) }
                    documents = TranscriptStore.all()
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}
