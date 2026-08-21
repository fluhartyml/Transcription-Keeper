//
//  DiarizationService.swift
//  Transcription Keeper
//
//  WHO said it, not just what was said.
//
//  Michael asked for this after seeing a PLAUD recorder on Amazon — a credit-card
//  sized device selling for $150–200 PLUS a subscription, whose headline feature is
//  transcribing a meeting and telling the speakers apart. Transcription Keeper
//  already does the transcribing, on the machine, for nothing. This is the half it
//  was missing.
//
//  Apple does NOT do speaker diarization. SpeechAnalyzer and SFSpeechRecognizer both
//  return words and timings and never a speaker. So this uses FluidAudio, an
//  on-device Swift package — which means the audio still never leaves the Mac. That
//  is the whole argument against the gadget: same feature, no cloud, no rent.
//
//  ─────────────────────────────────────────────────────────────────────────────
//  ⚠️ THIS FILE COMPILES TO NOTHING UNTIL THE PACKAGE IS ADDED, AND THAT IS
//  MICHAEL'S CLICK, NOT MINE. In Xcode: File → Add Package Dependencies… →
//  https://github.com/FluidInference/FluidAudio  (pin to a REVISION, not a branch —
//  Lighthouse follows 8a2bf2c). Adding a package rewrites a shipping app's project
//  file, and this app is LIVE on the Mac App Store; that is his decision to make in
//  his own editor.
//
//  Until then the `#warning` below fires on every build so this cannot be mistaken
//  for a working feature. Silence would be the false green that cost a whole morning
//  on 2026-08-20 — code that compiles clean because `canImport` failed and every
//  call site quietly vanished.
//  ─────────────────────────────────────────────────────────────────────────────
//
//  PORTED FROM LIGHTHOUSE, with one deliberate change: Lighthouse wraps its version
//  in `#if os(iOS)`, so its diarization does not run on the Mac at all. FluidAudio
//  itself supports macOS 14+ (read from the package manifest, not assumed), so that
//  guard was a self-imposed limit rather than a real one — and this version drops it,
//  which costs nothing and means the same file works wherever the app runs.
//
//  (I first wrote "this app IS the Mac" here and it was wrong. Transcription Keeper
//  is an iOS app — IPHONEOS_DEPLOYMENT_TARGET only, listed on the store as iOS 1.1.
//  An apartment note from 2026-08-19 calls it a Mac App Store app and that note is
//  mistaken. It builds for My Mac through Designed for iPad, which is what made the
//  claim look true.)
//
//  THE DESIGN POINT, and it is the reason this shipped at all: the spike on
//  2026-08-19 over-split a doctor into a third voice, and I treated that as a reason
//  to leave the feature out. Michael corrected it — "the third person split was an
//  annoyance that could have easily been corrected by the user, not a disqualifier
//  for at least trying." So the speaker labels are A SUGGESTION THE USER CORRECTS,
//  not a claim the app has to get right. `expectedSpeakers` is the knob that governs
//  the split, and it defaults to 1 because asking for two voices when there is only
//  one FORCES a split — his own test proved that, recording himself alone.
//

import Foundation

/// One stretch of audio attributed to one speaker.
///
/// Declared OUTSIDE the package guard on purpose: anything that lays out a transcript
/// has to compile whether or not FluidAudio is linked, so the app still builds and
/// runs — with a single unattributed speaker — before the dependency is added.
struct SpeakerSpan: Sendable, Identifiable {
    let id = UUID()
    let speaker: String
    let start: Double
    let end: Double
}

#if canImport(FluidAudio)
import AVFoundation
import FluidAudio

enum DiarizationService {

    /// Split a recording into stretches of speech, one speaker each.
    ///
    /// - Parameter expectedSpeakers: how many voices to expect. **1 by default.**
    ///   Asking for two when only one person spoke forces a split — Michael found
    ///   that by recording himself alone and coming back as two people. At 1 the
    ///   diarizer is skipped entirely and the whole recording is one speaker, which
    ///   is both faster and correct for the common case.
    static func diarize(fileAt url: URL, expectedSpeakers: Int = 1) async throws -> [SpeakerSpan] {
        guard expectedSpeakers > 1 else {
            return []          // one voice: nothing to separate
        }
        let samples = try readMono16k(url: url)
        guard !samples.isEmpty else { return [] }

        var config = DiarizerConfig()
        config.numClusters = expectedSpeakers
        let diarizer = DiarizerManager(config: config)
        let models = try await DiarizerModels.downloadIfNeeded()
        diarizer.initialize(models: models)
        let result = try diarizer.performCompleteDiarization(samples, sampleRate: 16000)
        return result.segments.map {
            SpeakerSpan(speaker: $0.speakerId,
                        start: Double($0.startTimeSeconds),
                        end: Double($0.endTimeSeconds))
        }
    }

    /// Decode any audio file to the 16 kHz mono floats the diarizer expects.
    private static func readMono16k(url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let inFormat = file.processingFormat
        guard let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                            sampleRate: 16000,
                                            channels: 1,
                                            interleaved: false),
              let converter = AVAudioConverter(from: inFormat, to: outFormat),
              let inBuffer = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: 65536)
        else { return [] }

        var samples: [Float] = []
        let ratio = 16000.0 / inFormat.sampleRate
        let outCapacity = AVAudioFrameCount(Double(65536) * ratio) + 32

        while true {
            guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: outCapacity) else { break }
            var reachedEnd = false
            var conversionError: NSError?
            let status = converter.convert(to: outBuffer, error: &conversionError) { _, outStatus in
                do {
                    inBuffer.frameLength = 0
                    try file.read(into: inBuffer)
                    if inBuffer.frameLength == 0 {
                        reachedEnd = true
                        outStatus.pointee = .endOfStream
                        return nil
                    }
                    outStatus.pointee = .haveData
                    return inBuffer
                } catch {
                    reachedEnd = true
                    outStatus.pointee = .endOfStream
                    return nil
                }
            }
            if let channel = outBuffer.floatChannelData?[0], outBuffer.frameLength > 0 {
                samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(outBuffer.frameLength)))
            }
            if reachedEnd || status == .endOfStream || conversionError != nil { break }
        }
        return samples
    }
}

/// True when speaker separation is actually available in this build. The UI reads
/// this rather than assuming — a feature that is only sometimes compiled in must
/// never be advertised when it is not there.
let diarizationAvailable = true

#else

/// Speaker separation is not in this build; FluidAudio has not been added yet.
let diarizationAvailable = false

#warning("FluidAudio not linked — Transcription Keeper will transcribe but not separate speakers. Add the package in Xcode: File ▸ Add Package Dependencies ▸ https://github.com/FluidInference/FluidAudio (pin to a revision).")

#endif
