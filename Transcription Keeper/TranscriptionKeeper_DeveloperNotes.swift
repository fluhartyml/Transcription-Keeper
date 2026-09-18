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
//  [x] Speaker diarization — "Speaker 1" / "Speaker 2" labels        WIRED 2026-09-17
//      FluidAudio, on-device, pinned. DiarizationService had existed since build 8
//      with the package linked — and NOTHING CALLED IT. Michael remembered labelling
//      himself and his doctor and being split into an extra voice; that was the
//      2026-08-19 spike and Lighthouse, never this app. Now wired:
//        · a speaker-count stepper, set BEFORE recording (the diarizer is told how
//          many voices to cluster into, so it cannot be inferred afterwards)
//        · timed tokens kept from SFSpeechRecognizer — formattedString throws the
//          timings away and the diarizer answers in seconds, so without them the two
//          halves cannot be joined
//        · SpeakerLayout, ported from Lighthouse's layOutDetectingSpeakers
//        · BOTH capture paths routed through one function, because a feature wired
//          into only push-to-talk or only classic would simply not exist in the other
//      ⬜ STILL OPEN: renaming "Speaker 1" to a real name. The labels are a guess the
//         user corrects — Michael's ruling — and today there is nowhere to correct
//         them. That is the next piece, and it is what the Dec 2 appointment needs.
//      ⬜ NOT ADVERTISED YET: the App Store description and the landing page do not
//         mention speaker separation. Correct until it is tested in a real room.
//
//  [ ] PTT INTERVIEW MODE — tag the cards. HIS DESIGN, 2026-09-17.
//      ⛔ THIS IS NOT DIARIZATION AND MUST NOT BE BUILT ON IT. In push-to-talk the
//         app ALREADY KNOWS where the speaker changes: the button press IS the
//         boundary. Diarization is acoustic guesswork trying to recover a line the
//         interface hands over for free. His framing that got here: "the ptt would be
//         one person or maybe if they were doing an interview it could flag speaker
//         name one vs speaker name 2."
//
//      HIS SHAPE, in his words:
//        "maybe the interviewer controls the ptt the whole interview ... can the
//         interviewer wait till finished and then have the ptt bursts presented as
//         cards or something and the speakers up to 5 (random number) and the
//         interviewer fills out the participants names before or after the interview
//         (i would suggest before) then next to the cards are five color coded
//         speaker tags and the interviewer tags each card with the speaker"
//
//      ⛔ WHY ONE PERSON HOLDS THE BUTTON — and it RULES OUT the obvious alternative.
//         His observation, 2026-09-17: "an iphone is a personal device that the
//         interviewer probably wouldnt trust passing the phone around for each person
//         to PTT."
//         **Pass-the-phone — each participant pressing their own bursts — is DEAD.**
//         It is the design a reasonable person reaches for first, because it would make
//         every burst self-labelling and the tagging pass unnecessary. It fails for a
//         reason no amount of engineering fixes: nobody hands their unlocked phone to a
//         stranger, a doctor, or four people in a room. ⚠️ Do not resurrect it.
//
//      📡 AND IT SETTLES THE MICROPHONE QUESTION, which cuts against diarization again:
//         the phone stays at the INTERVIEWER'S position, so every other voice is
//         recorded off-axis and at distance, through one mic, at different volumes.
//         That is the hardest possible input for acoustic clustering — and the easiest
//         for a human tagging cards, who is reading words and not waveforms. It is also
//         exactly the case Apple built SpeechTranscriber for ("speakers not close to
//         mic"), so the transcription half holds up where the clustering half would not.
//
//      🔒 IT ALSO EXPLAINS WHY TAGGING-AFTER WORKS AT ALL: the interviewer never gives
//         up custody of the device, so the person who ran the interview is the same
//         person reviewing the cards, with the conversation still fresh. A tagging pass
//         that depended on handing the phone around would have neither property.
//
//        · ONE PERSON HOLDS THE BUTTON for the whole interview — the interviewer.
//          Everyone speaks into it; the interviewer works the press-and-release.
//        · TAGGING IS A POST-PASS. Bursts are presented as CARDS after the interview
//          is finished, not tagged live. Nobody can run an interview and tag it at
//          the same time — the same load that made short bursts the unit.
//        · PARTICIPANT NAMES ARE FILLED IN FIRST. "i would suggest before" — his call,
//          and it is the right one: tags have to exist before there is anything to tag
//          a card WITH.
//        · FIVE COLOUR-CODED SPEAKER TAGS beside the cards; tagging is a visual match
//          rather than typing a name five hundred times.
//        ⚠️ FIVE IS HIS OWN "(random number)" — his words. It is a starting point, NOT
//          a measured limit, and nothing should be built that treats 5 as a constraint.
//
//      ⭐ THE GENERALISATION — HIS, 2026-09-17, AND IT RESHAPES THE FEATURE.
//         "maybe the student uses those tags for something else like one person talking
//          but shifting across five topics? if so then maybe the interviewee or subject
//          tag number is defined by the user"
//
//         **THE TAG IS NOT A SPEAKER. The tag is a user-defined dimension, and SPEAKER
//         is only its most obvious instance.** One person recording alone, moving
//         through five topics, wants the same cards and the same coloured tags — and
//         nothing about the mechanism cares which meaning is loaded into it.
//
//         | Who | What the tags are |
//         |---|---|
//         | interviewer | the participants |
//         | a student | the topics in a lecture |
//         | Michael, dictating | sections of a report |
//
//         ⛔ CONSEQUENCES, and they are not cosmetic:
//           · **The USER names the dimension and the labels** — not the app, and not a
//             hardcoded "Speaker N". "Speaker 1" becomes a DEFAULT for one use case
//             rather than the model everything is built on.
//           · **The USER sets the count.** This retires the earlier "(random number)"
//             five for good: it was never a limit and now it is not even a default —
//             three topics, or eight participants, are the user's call.
//           · **It widens who the app is for.** A student taking lecture notes is a new
//             audience, and it arrived from him, not from market reasoning.
//
//         ⬜ REASONING, NOT HIS RULING — flagged so it is not mistaken for decided:
//           if a burst carries a tag, tags could DRIVE the Composition ladder. Every
//           card tagged "topic 3" collecting into one page would make the tag the thing
//           that assembles the document, not just annotates it. That is a large idea
//           and it is NOT decided. Ask before building toward it.
//
//      WHY THIS IS STRICTLY BETTER THAN DIARIZATION *FOR PTT*: it cannot over-split,
//      because it never clusters. The doctor who became a third voice on 2026-08-19
//      is impossible here — a card belongs to exactly one press, and a person decides
//      whose it is.
//
//      ⬜ OPEN, NOT DECIDED — do not assume either way:
//        · A burst where two people talk over each other. Split a card? Two tags?
//        · Untagged cards at publish — blocked, or published unattributed?
//        · Does a tagged card still climb the Composition ladder (burst → paragraph →
//          page)? It should — a tag describes a burst, it does not replace it — but
//          that is reasoning, not his ruling.
//        · Whether the meeting recorder ever offers cards too, with diarization's
//          guesses PRE-TAGGED for correction. That would make one review surface for
//          both modes, and it is exactly what "labels are a guess the user corrects"
//          has always implied.
//
//      SO THE SPLIT IS: meeting/squelch → diarization, because many voices share one
//      continuous recording and nothing marks the handoffs. PTT → card tagging,
//      because the handoffs are already marked. Two mechanisms, chosen by what the
//      capture mode actually knows.
//
//  [ ] Rename detected speakers — "Speaker 1" → "Dr. Prasad"
//      detectedSpeakers already reports which labels a transcript used, so the
//      rename screen does not need to re-run the diarizer.
//
//  [ ] Composition — the third tab. Full design in DEVELOPER-NOTES.md (2026-09-15):
//      the ladder burst → paragraph → page → publish, a meeting entering as ONE page,
//      the chain holding mixed sizes, and a page that keeps audio while discarding its
//      transcript. The genuinely new control is "this capture is done" — it exists in
//      neither mode today. ⛔ Nothing commits on a timer, a pause or a silence gap.
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
