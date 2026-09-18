//
//  SpeakerLayout.swift
//  Transcription Keeper
//
//  Turning "what was said" into "who said it" — the half the app was missing.
//
//  PORTED FROM LIGHTHOUSE (`NoteTranscriptionService.layOutDetectingSpeakers`), which
//  is the version Michael has actually used against a real doctor's visit. It is
//  copied rather than reinvented because it already survived contact with the thing
//  it is for, including the failure that matters: the 2026-08-19 spike over-split a
//  doctor into a third voice.
//
//  ⚠️ ONE DELIBERATE DEVIATION FROM LIGHTHOUSE, and it is here because the two apps
//  use different speech engines. Lighthouse's tokens carry their own spacing;
//  `SFSpeechRecognizer` hands back bare words with no spaces at all
//  (`SFTranscriptionSegment.substring` is "the", not " the"). Appending those the way
//  Lighthouse does would produce "thepatientsaysyes". So this version inserts the
//  separator itself — see `append` below. Everything else is Lighthouse's logic,
//  unchanged on purpose.
//
//  THE DESIGN POINT, which is Michael's and is why generic labels are correct:
//  "the third person split was an annoyance that could have easily been corrected by
//  the user, not a disqualifier for at least trying." The app is GUESSING. A guess
//  does not get to put a name on someone, so the labels are "Speaker 1", "Speaker 2"
//  in order of first appearance and the user renames them afterwards.
//

import Foundation

/// One word (or short run) of recognised speech, with the time it occupied.
///
/// Declared outside every package guard, like `SpeakerSpan`, so the transcript can be
/// laid out whether or not FluidAudio is linked into this build.
struct Token: Sendable {
    let text: String
    let start: Double
    let end: Double
}

enum SpeakerLayout {

    /// Lay a transcript out by speaker using the diarizer's spans, and report which
    /// generic labels were used so a rename screen can list them later without
    /// re-running the diarizer.
    ///
    /// - Parameter names: optional display names keyed by generic label
    ///   ("Speaker 1" → "Dr. Prasad"). Empty means "show the generic labels".
    static func layOutDetectingSpeakers(tokens: [Token],
                                        spans: [SpeakerSpan],
                                        names: [String: String] = [:]) -> (text: String, speakers: [String]) {
        guard !tokens.isEmpty else { return ("", []) }

        var labelFor: [String: String] = [:]
        var next = 1
        func label(_ id: String) -> String {
            if let existing = labelFor[id] { return existing }
            let generic = "Speaker \(next)"
            next += 1
            labelFor[id] = generic
            return generic
        }
        func speaker(at t: Double) -> String? {
            spans.first { t >= $0.start && t <= $0.end }?.speaker
        }

        var lines: [String] = []
        var current: String?
        var buffer = ""
        // The last speaker the diarizer actually had an opinion about.
        var lastKnown = "Speaker 1"

        // The spacing fix described in the file header.
        func append(_ word: String, to buffer: inout String) {
            buffer += buffer.isEmpty ? word : " " + word
        }

        for token in tokens {
            let mid = (token.start + token.end) / 2
            // A gap in the spans means the diarizer had NO OPINION about this moment —
            // not that a different person spoke. Carrying the previous speaker forward
            // is truer to what the diarizer said than inventing a placeholder, and a
            // placeholder could never be renamed because it was never a real speaker.
            let raw: String
            if spans.isEmpty {
                raw = "Speaker 1"
            } else if let found = speaker(at: mid).map(label) {
                raw = found
                lastKnown = found
            } else {
                raw = lastKnown
            }
            let shown = names[raw] ?? raw
            if shown != current {
                if let c = current, !buffer.trimmingCharacters(in: .whitespaces).isEmpty {
                    lines.append("\(c): \(buffer.trimmingCharacters(in: .whitespaces))")
                }
                current = shown
                buffer = ""
                append(token.text, to: &buffer)
            } else {
                append(token.text, to: &buffer)
            }
        }
        if let c = current, !buffer.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append("\(c): \(buffer.trimmingCharacters(in: .whitespaces))")
        }

        // In order of first appearance, which is the order they read in.
        let used = labelFor.values.sorted { a, b in
            (Int(a.dropFirst(8)) ?? 0) < (Int(b.dropFirst(8)) ?? 0)
        }
        return (lines.joined(separator: "\n\n"), used.isEmpty ? ["Speaker 1"] : used)
    }
}
