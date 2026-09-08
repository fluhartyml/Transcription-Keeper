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

    // MARK: - Push to talk
    //
    // Michael, 2026-09-08: "i would imagine it replaces the gain slider and the record
    // shutter." It does, and the slider went with it on purpose — a threshold is the app
    // GUESSING when you meant to speak. Push to talk is you saying so. Once the finger is
    // the switch there is nothing left for a sensitivity control to decide.
    /// Which instrument is on screen. Remembered between launches — a mode you have to
    /// re-pick every time is a mode you stop using.
    @AppStorage("usePushToTalk") private var usePushToTalk = true

    @State private var isTalking = false

    /// Squelch's setting, held while push to talk borrows the gate. Zeroing the threshold
    /// and not putting it back would hand the slider back to him sitting at 0.
    @State private var savedThreshold: Float?
    @State private var dragOffset: CGFloat = 0

    /// How far down the finger travels before letting go throws the take away.
    private let cancelDistance: CGFloat = 90

    /// ⚠️ THE ABORT IS NOT A NICETY. His rule, 2026-09-07: "if I say never mind it should
    /// cancel" / "can the PTT have a pull mouse away cancel action equivilant?"
    /// A push to talk with no cancel sends every misfire.
    private var willCancel: Bool { isTalking && dragOffset > cancelDistance }

    private var pushToTalkLabel: String {
        if !isTalking { return "Hold to Talk" }
        return willCancel ? "Release to cancel" : "Slide down to cancel"
    }
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

    // ⚠️ THIS BLOCK IS ALWAYS IN THE LAYOUT, EVEN WHEN IT SHOWS NOTHING.
    //
    // Michael, 2026-09-08: "before recording on either the squelch slider or the ptt
    // while recording the counter appears sliding the ptt under your finger, looks like
    // an accidental undo."
    //
    // It was inserted with `if recorder.isSessionActive`, so starting a take grew the
    // stack and pushed everything below it DOWN — including the push-to-talk button,
    // which travels down for exactly one reason: cancel. The finger never moved. The
    // instrument moved under it, and it looked like the take had just been thrown away.
    //
    // His follow-up, same minute: "the counter should always be there." So it is not
    // hidden and spaced — it is ALWAYS SHOWING, reading zero when idle. An instrument's
    // display stays lit; a readout that appears when you start is a readout you cannot
    // check BEFORE you start.
    // Reserving the height costs nothing and means the button is nailed to the glass.
    // An instrument you operate without looking cannot move while you are holding it.
    /// The DIGITS are the glass, not a card behind them.
    ///
    /// Michael, 2026-09-08, correcting the first attempt: "i was describing the actual
    /// numbers being glass almost clear not a card with the nubers zero because the card
    /// dissapears and then the numbers turn red."
    ///
    /// The first version put a glass panel around the counter, so starting a take made a
    /// whole card vanish — a second thing moving on screen at the exact moment he is
    /// holding a button that cancels on movement. Now nothing appears or disappears.
    /// The same numerals are always in the same place and only their MATERIAL changes:
    /// near-clear glass at rest, solid colour once a take is being kept.
    private var counterStack: some View {
        VStack(spacing: 4) {
            Group {
                if recorder.isSessionActive {
                    counterText.foregroundStyle(counterColor)
                } else {
                    // Glass in the shape of the glyphs: the effect is masked BY the text,
                    // so the numerals themselves are the window rather than sitting on one.
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(in: .rect(cornerRadius: 0))
                        .mask { counterText }
                        .frame(height: 58)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: recorder.isSessionActive)

            Text("Session: \(formatDuration(recorder.sessionDuration))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 76)
        .frame(maxWidth: .infinity)
    }

    private var counterText: Text {
        Text(formatDuration(recorder.capturedDuration))
            .font(.system(size: 48, weight: .light, design: .monospaced))
    }

    /// Red only while a take is actually being kept.
    private var counterColor: Color {
        if willCancel { return .secondary }
        return recorder.isSessionActive ? .red : .secondary
    }

    private var durationDisplay: some View { counterStack }

    // MARK: - Recording View

    // MARK: - Recording View
    //
    // ⚠️ TWO MODES, AND THE TOGGLE IS THE POINT. Michael, 2026-09-08, after the first
    // build shipped with the old mode deleted: "where is the toggle to switch between
    // squelch record shutter and PTT it only says hold to talk and is no slider."
    // The branch is called ptt-toggle. "Replaces the gain slider and the record shutter"
    // meant replaces them WHILE PUSH TO TALK IS ON, not instead of them forever.
    //
    // His labels, 2026-09-08: "meeting and PTT". Meeting is the voice-activated mode —
    // set the squelch and let it run through a conversation. PTT is deliberate: nothing is
    // kept unless a finger is down. The names say what the mode is FOR, not how it works.

    private var recordingView: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $usePushToTalk) {
                Text("Meeting").tag(false)
                Text("PTT").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 30)
            .padding(.top, 8)
            // Switching modes mid-take would leave a recording running with no control
            // on screen to stop it. Close the take first, then change the instrument.
            .disabled(recorder.isSessionActive || transcriptionService.isTranscribing)

            if usePushToTalk {
                pushToTalkRecordingView
            } else {
                classicRecordingView
            }
        }
    }

    private var pushToTalkRecordingView: some View {
        VStack(spacing: 24) {
            Spacer()

            // The level meter STAYS. With the threshold gone it is no longer a control,
            // it is the only proof the microphone is hearing anything at all.
            VStack(spacing: 8) {
                Text("Audio Level")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(levelColor)
                            .frame(width: geometry.size.width * CGFloat(recorder.currentLevel))
                    }
                }
                .frame(height: 24)
            }
            .padding(.horizontal, 30)

            durationDisplay

            Spacer()

            pushToTalkButton

            Text(pushToTalkLabel)
                .font(.caption)
                .foregroundStyle(willCancel ? Color.red : Color.secondary)
                .animation(.easeInOut(duration: 0.15), value: willCancel)

            Spacer()
        }
    }

    private var pushToTalkButton: some View {
        ZStack {
            Circle()
                .fill(willCancel ? Color.gray : Color.red)
                .frame(width: isTalking ? 104 : 80, height: isTalking ? 104 : 80)

            Image(systemName: willCancel ? "xmark" : "mic.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isTalking)
        .offset(y: min(max(dragOffset, 0), cancelDistance))
        // minimumDistance 0 so the press itself starts the take — a hold that only
        // begins after the finger MOVES would clip the first word off every sentence.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isTalking { beginTalking() }
                    dragOffset = value.translation.height
                }
                .onEnded { _ in
                    endTalking(cancelled: willCancel)
                }
        )
        .disabled(transcriptionService.isTranscribing)
    }

    private func beginTalking() {
        isTalking = true
        dragOffset = 0
        showingResults = false

        // ⚠️ OPEN THE GATE. The recorder only captures above its threshold, which is
        // correct for voice activation and wrong here — the finger already said "now".
        // Leaving it at 0.15 would silently drop quiet speech while the button is held.
        savedThreshold = recorder.threshold
        recorder.threshold = 0
        recorder.startRecording()
    }

    private func endTalking(cancelled: Bool) {
        isTalking = false
        dragOffset = 0

        // Give squelch its setting back before anything else can read it.
        if let savedThreshold { recorder.threshold = savedThreshold }
        savedThreshold = nil

        let url = recorder.stopRecording()

        if cancelled {
            // Throw the take away rather than transcribing it. Deleting the file is the
            // point — a cancelled recording that stays on disk is not cancelled.
            if let url { try? FileManager.default.removeItem(at: url) }
            recorder.startMonitoring()
            return
        }

        guard let url else {
            recorder.startMonitoring()
            return
        }

        lastRecordingURL = url
        Task {
            await transcriptionService.transcribe(audioURL: url)
            showingResults = true
        }
    }

    private var classicRecordingView: some View {
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
            durationDisplay

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
