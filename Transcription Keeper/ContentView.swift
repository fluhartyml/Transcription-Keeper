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

    /// At rest these are drawn in clear — present, sized, invisible. His fix.
    private var statusDotColor: Color {
        guard recorder.isSessionActive else { return .clear }
        return recorder.isCapturing ? .red : .orange
    }

    private var statusTextColor: Color {
        guard recorder.isSessionActive else { return .clear }
        return recorder.isCapturing ? .red : .orange
    }

    /// "Listening..." is the widest of the three, so it is what holds the row open.
    private var statusText: String {
        guard recorder.isSessionActive else { return "Listening..." }
        return recorder.isCapturing ? "Recording" : "Listening..."
    }

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

            // ⭐ STATUS ROW — ALWAYS PRESENT, INVISIBLE WHEN IDLE.
            //
            // MICHAEL FOUND THIS, 2026-09-08, after three wrong diagnoses from me:
            // "i found it, its the 'listening. ..' it causes everything to slide down."
            // It was wrapped in `if recorder.isSessionActive`, so starting a take INSERTED
            // a row at the top of the screen and pushed the entire layout down — including
            // the push-to-talk button, under a thumb that had not moved, in the direction
            // that means cancel.
            //
            // And the fix is his too: "maybe have invisable letters." The row is now always
            // in the layout at a fixed height; at rest the dot and the letters are simply
            // drawn in clear. The space is occupied whether or not anything is showing, so
            // there is nothing left that can move.
            HStack(spacing: 8) {
                if transcriptionService.isTranscribing {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(transcriptionService.statusMessage)
                        .font(.headline)
                        .foregroundStyle(.blue)
                } else {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 12, height: 12)
                    Text(statusText)
                        .font(.headline)
                        .foregroundStyle(statusTextColor)
                }
            }
            // ⚠️ NO FORCED HEIGHT. Clamping this to 22pt made ".headline" text draw OUTSIDE
            // its frame — SwiftUI overflows rather than shrinking — and "Listening..."
            // landed on top of the mode picker. His report: "listening appears over the
            // tabs." The row does not need a clamp: it is always in the layout now, with
            // the same font in every state, so its height is already constant.

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
        // ⛔ THE CONTAINER MUST BE THE SCREEN, OR THE INSET RIDES THE CONTENT.
        //
        // His report, 2026-09-14, on an iPhone 16e: "the (i) is under the battery and i can
        // not tap it" — and only in PTT mode. The transcript screens placed it correctly.
        //
        // ⚠️ `.safeAreaInset` BELOW IS ATTACHED TO THIS VSTACK, NOT TO THE WINDOW. A VStack
        // sizes to its content and centres, so when PTT mode makes the content taller —
        // level meter, session counter, the big hold-to-talk button — the stack overflows
        // UPWARD and the inset goes with it, straight under the status bar. Outside the
        // safe area there is nothing to tap: the hit test never reaches it.
        //
        // Filling the container first pins the inset to the SCREEN's safe area, which is
        // what the earlier fix intended. It works the same on a notch and on the Dynamic
        // Island — "the island messed things up," and the point of an inset is that the
        // island's height stops being a number anyone has to know.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        // His report, 2026-09-08: "the (i) is too small and squished under the battery."
        // Then, after more padding: "top of the (i) circle is under the battery."
        //
        // ⚠️ PADDING WAS THE WRONG TOOL. An overlay is positioned against the view's own
        // bounds, which run up under the status bar, so clearing the battery meant guessing
        // a number — and the number that works on one phone is wrong on the next, because
        // the Dynamic Island is a different height from a notch and different again from
        // neither.
        //
        // safeAreaInset places the button INSIDE the safe area by construction. It clears
        // the status bar on every device without a magic number, and because it reserves
        // its own row it cannot overlap anything below it either.
        .safeAreaInset(edge: .top, alignment: .trailing, spacing: 0) {
            Button {
                showingAbout = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .padding(.trailing, 14)
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
                    // ⚠️ SAME HEIGHT AS THE GLASS BRANCH, EXPLICITLY. Letting this one take
                    // its intrinsic size made the two states differ by a few points, and
                    // those points moved the button under his finger the moment a take
                    // started. Reported twice — the second time as "on the push to talk the
                    // counter makes the pt button slide down."
                    counterText
                        .foregroundStyle(counterColor)
                        .frame(height: 58)
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
            .frame(height: 58)

            Text("Session: \(formatDuration(recorder.sessionDuration))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 86)
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
                .frame(height: 18)
                .animation(.easeInOut(duration: 0.15), value: willCancel)

            Spacer()
        }
    }

    /// ⚠️ THIS VIEW DOES NOT MOVE. NOT BY A POINT, NOT FOR A MOMENT.
    ///
    /// Michael reported it four times on 2026-09-08 — "sliding the ptt under your finger",
    /// "the counter makes the pt button slide down", "the counter still slides", and
    /// finally "it moves in some sort of animation". Three different causes were found and
    /// fixed and it still moved, because each fix removed one mover and left another:
    /// a conditional counter that changed the layout height, two counter states of
    /// different sizes, a frame that grew from 80 to 104 when held, a spring that settled
    /// afterwards, and an offset that followed his thumb.
    ///
    /// The lesson is the one his Skills Lab already had: fixing the interesting mover and
    /// leaving the boring one is not a fix. So every source of motion is gone rather than
    /// tuned. **The only things that change are colour and wording.**
    ///
    /// The cancel still works exactly as before — the gesture measures how far his thumb
    /// has travelled. It simply no longer drags the instrument along with it. A machine
    /// you operate without looking has to be where you left it.
    private var pushToTalkButton: some View {
        ZStack {
            Circle()
                .fill(willCancel ? Color.gray : Color.red)
                .frame(width: 96, height: 96)

            Image(systemName: willCancel ? "xmark" : "mic.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 110, height: 110)
        .contentShape(Circle())
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
