//
//  TranscriptionKeeper_DeveloperNotes.swift
//  Transcription Keeper
//
//  Developer Notes — Persistent Memory for AI Assistants
//  Created: 2025 NOV 27 (Claude Code)
//

// ============================================================================
// MARK: - PROJECT IDENTITY
// ============================================================================
//
//  Name:           Transcription Keeper
//  Bundle ID:      com.NightGard.Transcription-Keeper
//  Platform:       iOS (Universal)
//  Version:        1.0
//  Deployment:     iOS 26.1
//  Status:         LIVE on App Store
//  Location:       /Users/michaelfluharty/Developer/NightGard/Transcription Keeper/

// ============================================================================
// MARK: - DESCRIPTION
// ============================================================================
//
//  Voice recording app with smart threshold-based voice activity detection
//  and automatic speech-to-text transcription via Apple's SFSpeechRecognizer.
//  Record only when you're speaking, transcribe when done, share text or audio.

// ============================================================================
// MARK: - ARCHITECTURE
// ============================================================================
//
//  Transcription_KeeperApp.swift      — App entry point
//  ContentView.swift                   — Main UI: header, status, level meter, slider,
//                                        record button, results, share buttons
//  SmartAudioRecorder.swift            — @Observable: VAD threshold recording, real-time
//                                        metering (20Hz), grace period (0.8s), mono 44.1kHz AAC
//  TranscriptionService.swift          — @Observable: SFSpeechRecognizer, async/await,
//                                        URL-based recognition, locale support
//  ShareSheet.swift                    — UIActivityViewController wrapper
//  GlyphPreview.swift                  — SF Symbol browser (not compiled)

// ============================================================================
// MARK: - KEY FEATURES
// ============================================================================
//
//  Voice Activity Detection (VAD):
//    - Adjustable threshold (0.05-0.8, default 0.15)
//    - Grace period (0.8s) continues recording after voice drops
//    - Real-time audio level metering at 20Hz
//    - Monitoring mode for threshold preview without recording
//
//  Recording:
//    - Mono, 44.1kHz, MPEG4 AAC, high quality
//    - ISO8601 timestamp filenames in temp directory
//    - Session duration vs captured duration tracking
//
//  Transcription:
//    - Apple SFSpeechRecognizer (on-device)
//    - Async/await with continuation pattern
//    - Per-user locale support
//    - Fallback message if no speech detected
//
//  UI:
//    - Status indicators: Recording (red), Listening (orange), Transcribing (spinner)
//    - Audio level meter with threshold line
//    - Sensitivity slider with percentage
//    - 80x80 red record button
//    - Results view with Share Text + Share Audio buttons
//
//  Permissions: Microphone + Speech Recognition

// ============================================================================
// MARK: - EASTER EGG
// ============================================================================
//
//  "Engineered with Claude by Anthropic" — present in developer notes

// ============================================================================
// MARK: - ABOUT THIS APP
// ============================================================================
//
//  Transcription Keeper v1.0
//  "Your voice, transcribed."
//
//  Engineered with Claude by Anthropic
//  Copyright (c) 2025 Michael Fluharty
//  Licensed under CC BY-SA 4.0
//  Website: https://fluharty.me
//  Contact: michael@fluharty.me

// ============================================================================
// MARK: - SHAKEDOWN CHECKLIST
// ============================================================================
//
//  [ ] App launches without crash
//  [ ] Microphone permission prompt appears
//  [ ] Speech recognition permission prompt appears
//  [ ] Audio level meter responds to sound
//  [ ] Sensitivity slider adjusts threshold
//  [ ] Threshold line moves on meter
//  [ ] Record button starts recording
//  [ ] Status shows "Recording" (red dot) when capturing
//  [ ] Status shows "Listening..." (orange dot) when below threshold
//  [ ] Grace period keeps recording briefly after voice drops
//  [ ] Stop button ends recording
//  [ ] Transcription begins after recording stops
//  [ ] Transcription text appears in results
//  [ ] Share Text button opens share sheet
//  [ ] Share Audio button opens share sheet with audio file
//  [ ] New Recording button resets UI
//  [ ] Session duration displays correctly (MM:SS.d)
//  [ ] Captured duration displays correctly
//  [ ] Light/dark mode icons display correctly
//  [ ] App runs on iPhone
//  [ ] App runs on iPad

// ============================================================================
// MARK: - v2.0 ROADMAP (Active — 2026 MAR 27)
// ============================================================================
//
//  Priority: Apple Watch Companion App
//  ----------------------------------------
//  [ ] Add watchOS target to Xcode project
//  [ ] Watch UI — record button, status display, transcription result
//  [ ] WatchConnectivity framework (both sides)
//      - Watch records audio via AVAudioRecorder on watchOS
//      - Watch sends audio file to iPhone via WCSession transferFile
//      - iPhone receives and transcribes via SpeechAnalyzer
//      - iPhone sends transcription text back to Watch
//  [ ] Shared data model between iOS and watchOS targets
//  [ ] Watch app icon
//  [ ] Test on real Apple Watch hardware
//
//  Additional v2.0 Features:
//  ----------------------------------------
//  [ ] Save audio recordings — persist audio files alongside transcriptions
//  [ ] Real-time transcription while recording
//  [ ] Multiple recordings history
//  [ ] Export as .txt file
//  [ ] Copy to clipboard button
//  [ ] Language selection
//  [ ] Timestamps in transcription
//
//  Future (v3+):
//  ----------------------------------------
//  [ ] Speaker diarization — "Speaker 1" / "Speaker 2" labels
//      Research: FluidAudio (forked as research-swift-scribe)
//      Simpler option: "[Speaker changed]" markers
//
//  v2 Priority Note:
//  Apple Watch + audio saving adds substance and addresses Apple's
//  "too simple" rejection pattern for utility apps.

// ============================================================================
// MARK: - KNOWN ISSUES
// ============================================================================
//
//  (none currently)

// ============================================================================
// MARK: - DEVELOPER NOTES LOG
// ============================================================================
//
//  2026 MAR 27 — v2.0 roadmap added: Apple Watch companion app, audio saving,
//                recording history, timestamps. Watch app is today's build. (Claude Code)
//  2026 MAR 20 — Developer notes documented with shakedown checklist. (Claude Code)
//  2025 NOV 27 — Built and submitted to App Store on Thanksgiving. Single session
//                from planning to submission. (Claude Code)
//
