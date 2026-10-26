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

    /// How many voices to expect. **1 by default, and that default is load-bearing:**
    /// asking for two when only one person spoke FORCES a split — Michael proved that
    /// by recording himself alone and coming back as two people. At 1 the diarizer is
    /// skipped entirely, which is both faster and correct for the common case.
    @State private var expectedSpeakers = 1

    /// The generic labels the last transcript actually used ("Speaker 1", "Speaker 2").
    @State private var detectedSpeakers: [String] = []
    @State private var showingShareText = false
    @State private var showingShareAudio = false

    private var mainColumn: some View {
        VStack(spacing: 24) {
            // Title
            // ⛔ THE (i) LIVES BESIDE THE HERO, NOT AT THE TOP OF THE SCREEN.
            //
            // His instruction, 2026-09-14: "put it at the same level as the top of the
            // hero" — after "i have a notch why put it all the way up there?"
            //
            // ⚠️ THAT QUESTION IS THE FIX. Two attempts fought the status bar instead of
            // leaving it alone: a guessed padding (wrong on every other device), then a
            // safe-area inset (correct in principle, and it still ended up under the
            // notch on his 16e). A control docked to the top edge has to negotiate with
            // whatever Apple put there — notch, Dynamic Island, or neither.
            //
            // Aligned to the hero image it never touches that region at all, so there is
            // no geometry left to get wrong and nothing to re-tune per device.
            ZStack(alignment: .topTrailing) {
                heroImage
                infoButton
            }

            titleText

            statusRow

            // Show results or recording UI
            if showingResults && !transcriptionService.isTranscribing {
                resultsView
            } else {
                recordingView
            }

            errorText
        }
        .padding()
    }

    private var heroImage: some View { heroImage(size: 100) }

    private func heroImage(size: CGFloat) -> some View {
        Image("KnightMicWaveform")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .cornerRadius(20)
            .frame(maxWidth: .infinity)
    }

    private var infoButton: some View {
        Button {
            showingAbout = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
    }

    // REM: one line, shrunk to fit. At his phone's larger text size the title
    // wrapped to two lines, and that extra line helped push Meeting mode off the
    // top (his report, 2026-10-23: "the hero image is cut off at the top").
    private var titleText: some View {
        Text("Transcription Keeper")
            .font(.largeTitle)
            .fontWeight(.bold)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    @ViewBuilder
    private var errorText: some View {
        if let error = recorder.errorMessage ?? transcriptionService.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .padding()
        }
    }

    private var statusRow: some View {
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
    }

    // MARK: - Wide layout (iPhone Duo, landscape, iPad)
    //
    // His layout, 2026-10-26, looking at the iPhone Duo simulator: "that red button needs
    // to be close to the human finger. on the duo the optomization language has setting
    // buttons and tools often used on the right under the wifi batteryy and signal dots" ·
    // "lets move the red record button under the time just shift right but not up and
    // lower the transcription keeper below the audio level with the hero image below that"
    // · "the 00:00:00 would be in the center above transcription keeper".
    //
    // Centre, top to bottom: mode, audio level, status, counter, title, hero.
    // Right rail: the (i) under the status bar, the record button at the bottom where the
    // thumb is. The rail is its own column, so nothing in the centre can move the button.
    //
    // His, after seeing all four front-screen positions: "the i should be under the time
    // signal strength column probably the tabs to so you can navigate with your thumb" ·
    // asked whether the (i) belongs at the bottom, he kept it at the top — it is the
    // least-used control, and next to a hold-to-talk button a slip would open About
    // mid-take.
    //
    // ⭐ TWO FRAMES ON THE FRONT SCREEN. His design, 2026-10-26: "left frame would have
    // everyentity that you see on my screen now and thr right frame has the clock the
    // battery circle with signal strenth circle thing where you could move the (i) tabs
    // and revord button to live in the right tab".
    //
    // iOS reports that right frame as a trailing safe-area inset (84 pt on the front
    // screen upright) but gives no height for the clock at its top — the status-bar frame
    // reads 466 × 2. So the controls are stacked UP FROM THE BOTTOM: red button, then
    // Meeting/PTT, then (i). They land under the clock without anyone knowing its height,
    // which is the guess that once put the (i) under the battery.
    //
    // No strip (sideways, the Duo open, iPad): the 130 pt rail beside the centre, (i) on top.
    //
    // ⚠️ THE ONE MEASURED NUMBER: the (i) sits 150 pt down, right under the Wi-Fi/battery
    // circle. His, 2026-10-26: "the (i) needs to be up right under the signal strength" —
    // the side button with the fingerprint reader is at that height, so the thumb is
    // already there. 150 was measured off the iPhone Duo simulator (iOS 27.1); a real Duo
    // or a larger text size may put the clock lower. He accepted that risk: "we will
    // probably have to redo all of this in november."
    private let clockStripClearance: CGFloat = 155

    /// His, 2026-10-26: "the (i) is off center and a few points too close to the circle,
    /// the ciecle should have close to the same distance from the time to the top as the
    /// (i) to the bottom". Measured off the simulator at 3x: clock 86–99 pt, circle top
    /// 110 (an 11 pt gap), its dots end at 151, the (i) glyph started at 157 — 6 pt. So
    /// 150 → 155. The system centres the circle at x 418, the strip's middle is 424, so
    /// the (i) moves 6 pt left to sit under it.
    private let clockStripCentreCorrection: CGFloat = -6

    private func wideLayout(screenHeight: CGFloat, strip: CGFloat, topInset: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if strip > 0 {
                stripCenterColumn
            } else {
                ViewThatFits(in: .vertical) {
                    wideCenterColumn(screenHeight: screenHeight)
                    ScrollView { wideCenterColumn(screenHeight: screenHeight) }
                        .scrollBounceBehavior(.basedOnSize)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            if strip == 0 {
                VStack(spacing: 16) {
                    infoButton
                    if showsRecordControls {
                        stackedModePicker(width: 100)
                    }
                    Spacer(minLength: 24)
                    if showsRecordControls {
                        recordControl(diameter: 96, narrow: false)
                    }
                }
                .frame(width: 130)
                .padding(.vertical)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            if strip > 0 {
                // His, 2026-10-26: "now the tabs and PTT are too low", then "have the red
                // PTT below the (i) but above (meeting)(PTT)". One stack from under the
                // clock: (i), red button, Meeting, PTT.
                //
                // Into the strip: the overlay is laid out inside the safe area, and the
                // strip is the trailing inset, so it moves right by exactly that inset.
                VStack(spacing: 16) {
                    infoButton
                        .offset(x: clockStripCentreCorrection)
                    if showsRecordControls {
                        recordControl(diameter: strip - 16, narrow: true)
                        stackedModePicker(width: strip - 8)
                    }
                }
                    .frame(width: strip)
                    .padding(.top, max(0, clockStripClearance - topInset))
                    .offset(x: strip)
            }
        }
    }

    /// The left frame on the Duo's front screen. His, 2026-10-26: "Transcription Keeper
    /// title should be on the bottom with the hero image center screen". Meter and counter
    /// stay at the top, the hero takes the middle, the title sits at the bottom beside the
    /// record button.
    private var stripCenterColumn: some View {
        VStack(spacing: 20) {
            if showingResults && !transcriptionService.isTranscribing {
                resultsView
                errorText
            } else {
                if usePushToTalk {
                    pushToTalkMeter
                } else {
                    classicMeter
                    speakerCount
                }
                statusRow
                durationDisplay
                errorText
                Spacer(minLength: 0)
                heroImage
                Spacer(minLength: 0)
                titleText
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var showsRecordControls: Bool {
        !(showingResults && !transcriptionService.isTranscribing)
    }

    @ViewBuilder
    private func recordControl(diameter: CGFloat, narrow: Bool) -> some View {
        if usePushToTalk {
            pushToTalkControl(diameter: diameter, narrow: narrow)
        } else {
            classicRecordControl(diameter: narrow ? diameter : 80, narrow: narrow)
        }
    }

    /// Meeting / PTT stacked, because the rail is too narrow for side-by-side tabs.
    /// Same rule as the segmented picker: no switching mid-take.
    private func stackedModePicker(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            modeButton("Meeting", pushToTalk: false, width: width)
            modeButton("PTT", pushToTalk: true, width: width)
        }
        .disabled(recorder.isSessionActive || transcriptionService.isTranscribing)
    }

    private func modeButton(_ title: String, pushToTalk: Bool, width: CGFloat) -> some View {
        let selected = usePushToTalk == pushToTalk
        return Button {
            usePushToTalk = pushToTalk
        } label: {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: width, height: 44)
                .background(selected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.12),
                            in: Capsule())
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// REM: the hero shrinks when the screen is short. Sideways on the Duo's front screen
    /// (his screens 2 and 4) the 100 pt image touched the bottom edge. A seventh of the
    /// screen height keeps it 100 on the tall screens and about 66 sideways; Claude's
    /// number, not his.
    private func wideCenterColumn(screenHeight: CGFloat) -> some View {
        VStack(spacing: 20) {
            if showingResults && !transcriptionService.isTranscribing {
                resultsView
            } else {
                if usePushToTalk {
                    pushToTalkMeter
                } else {
                    classicMeter
                    speakerCount
                }
                statusRow
                durationDisplay
            }

            errorText

            titleText
            heroImage(size: min(100, screenHeight / 7))
        }
        .padding()
    }

    var body: some View {
        // ⛔ THE HERO MUST NEVER LEAVE THE TOP OF THE SCREEN.
        //
        // His report, 2026-10-23, build 30 on the 16e: "it cuts off for the meeting tab but
        // comes back for the ptt tab." Meeting mode adds the sensitivity slider and the
        // speaker count; at his text size the column became taller than the screen, and a
        // too-tall stack centres — so it spilled off the TOP, hero and (i) first.
        //
        // REM: no guessed spacing numbers (the (i) history below shows where that leads).
        // If the column fits, it is drawn exactly as before. If it does not, the same
        // column goes in a scroll view, which starts at the top — so the hero is always
        // seen first and the rest is a scroll away instead of off the edge.
        //
        // REM: which layout is decided by the SHAPE of the space, not the device name —
        // the iPhone Duo notes: "size classes not idioms". A regular iPhone in portrait is
        // about twice as tall as it is wide (0.46 on the largest); the Duo's outer screen,
        // the Duo open, landscape and iPad are all wider than 0.6, and get the side rail.
        // The 0.6 line is Claude's choice, not his.
        //
        // ⚠️ MEASURE THE WHOLE SCREEN, SAFE AREA INCLUDED. The Duo's front screen puts the
        // clock and Wi-Fi in a column down the right side, which comes off the safe width —
        // measured inside it, the front screen (466 × 678 pt, 0.69) read as a regular
        // iPhone and kept the old layout. His screen, 2026-10-26, caught it.
        GeometryReader { geometry in
            let insets = geometry.safeAreaInsets
            let screenWidth = geometry.size.width + insets.leading + insets.trailing
            let screenHeight = geometry.size.height + insets.top + insets.bottom
            if screenWidth > screenHeight * 0.6 {
                // Only upright: sideways, the trailing inset is the camera's, not a clock strip.
                wideLayout(screenHeight: screenHeight,
                           strip: screenHeight > screenWidth ? insets.trailing : 0,
                           topInset: insets.top)
            } else {
                ViewThatFits(in: .vertical) {
                    mainColumn
                    ScrollView {
                        mainColumn
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
                    //
                    // REM: a faint copy of the digits sits under the glass. On a white
                    // background glass has nothing to bend and the counter vanished (seen
                    // on the iPhone Duo simulator, 2026-10-26). Same place, same size —
                    // nothing moves.
                    ZStack {
                        counterText
                            .foregroundStyle(.tertiary)
                        Rectangle()
                            .fill(.clear)
                            .glassEffect(in: .rect(cornerRadius: 0))
                            .mask { counterText }
                    }
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
            modePicker

            if usePushToTalk {
                pushToTalkRecordingView
            } else {
                classicRecordingView
            }
        }
    }

    private var modePicker: some View {
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
    }

    private var pushToTalkRecordingView: some View {
        VStack(spacing: 24) {
            Spacer()

            pushToTalkMeter

            durationDisplay

            Spacer()

            pushToTalkControl

            Spacer()
        }
    }

    // The level meter STAYS. With the threshold gone it is no longer a control,
    // it is the only proof the microphone is hearing anything at all.
    private var pushToTalkMeter: some View {
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
    }

    private var pushToTalkControl: some View { pushToTalkControl(diameter: 96) }

    /// `narrow` is the Duo's 84 pt clock strip: the wording gets two lines at a fixed
    /// height there, so "Slide down to cancel" fits without the label changing size.
    private func pushToTalkControl(diameter: CGFloat, narrow: Bool = false) -> some View {
        VStack(spacing: narrow ? 12 : 24) {
            pushToTalkButton(diameter: diameter)

            Text(pushToTalkLabel)
                .font(narrow ? .caption2 : .caption)
                .multilineTextAlignment(.center)
                .lineLimit(narrow ? 2 : 1)
                .foregroundStyle(willCancel ? Color.red : Color.secondary)
                .frame(height: narrow ? 30 : 18)
                .animation(.easeInOut(duration: 0.15), value: willCancel)
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
    private func pushToTalkButton(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(willCancel ? Color.gray : Color.red)
                .frame(width: diameter, height: diameter)

            Image(systemName: willCancel ? "xmark" : "mic.fill")
                .font(.system(size: diameter * 0.35, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: diameter + 14, height: diameter + 14)
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

    /// Transcribe, then — only if more than one voice was asked for — separate the
    /// speakers and re-lay the transcript with labels.
    ///
    /// Both recording modes funnel through here on purpose. The push-to-talk path and
    /// the classic path each used to call `transcribe` themselves, and a feature wired
    /// into one of them would simply not exist in the other.
    private func transcribeAndSeparate(url: URL) async {
        await transcriptionService.transcribe(audioURL: url)
        detectedSpeakers = []

        // Nothing to separate: one voice, no words, or the transcriber failed.
        guard expectedSpeakers > 1,
              !transcriptionService.tokens.isEmpty,
              transcriptionService.errorMessage == nil else { return }

        #if canImport(FluidAudio)
        transcriptionService.statusMessage = "Separating speakers…"
        do {
            let spans = try await DiarizationService.diarize(fileAt: url,
                                                             expectedSpeakers: expectedSpeakers)
            let laid = SpeakerLayout.layOutDetectingSpeakers(
                tokens: transcriptionService.tokens, spans: spans)
            // Only replace the transcript if the layout produced something. A silent
            // swap to an empty string would read as "the recording was lost".
            if !laid.text.isEmpty {
                transcriptionService.transcription = laid.text
                detectedSpeakers = laid.speakers
            }
            transcriptionService.statusMessage = "Transcription complete"
        } catch {
            // The words are already transcribed and on screen. Losing the speaker
            // labels must not take the transcript with it — say so and keep the text.
            transcriptionService.statusMessage = "Speakers could not be separated"
            transcriptionService.errorMessage =
                "Speakers could not be separated: \(error.localizedDescription). The transcript is still here."
        }
        #endif
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
            await transcribeAndSeparate(url: url)
            showingResults = true
        }
    }

    /// How many people are about to talk.
    ///
    /// ⚠️ THIS IS SET BEFORE RECORDING, NOT AFTER, and that is not a limitation — the
    /// diarizer is told how many voices to cluster into, so the number has to be a
    /// decision rather than something inferred from the audio. Michael's own phrasing
    /// on the Lighthouse version — "Just me talking" / "N people talking" — is kept
    /// word for word, because it asks the question in the terms the user is in.
    ///
    /// Hidden entirely when FluidAudio is not linked: a control that cannot do
    /// anything is worse than no control.
    @ViewBuilder
    private var speakerCount: some View {
        if diarizationAvailable {
            VStack(spacing: 4) {
                Stepper(value: $expectedSpeakers, in: 1...8) {
                    Text(expectedSpeakers == 1 ? "Just me talking" : "\(expectedSpeakers) people talking")
                        .font(.subheadline)
                }
                Text(expectedSpeakers == 1
                     ? "Speakers will not be separated."
                     : "Labels are a guess you can correct afterwards.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 30)
            // Changing it mid-recording would apply to audio already captured.
            .disabled(recorder.isSessionActive || transcriptionService.isTranscribing)
        }
    }

    private var classicRecordingView: some View {
        VStack(spacing: 24) {
            Spacer()

            classicMeter

            speakerCount

            // Duration display
            durationDisplay

            Spacer()

            classicRecordControl

            Spacer()
        }
    }

    private var classicMeter: some View {
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
    }

    private var classicRecordControl: some View { classicRecordControl(diameter: 80) }

    private func classicRecordControl(diameter: CGFloat, narrow: Bool = false) -> some View {
        VStack(spacing: narrow ? 12 : 24) {
            // Record Button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(recorder.isSessionActive ? Color.red : Color.red.opacity(0.8))
                        .frame(width: diameter, height: diameter)

                    if recorder.isSessionActive {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: diameter * 0.375, height: diameter * 0.375)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: diameter * 0.375, height: diameter * 0.375)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(transcriptionService.isTranscribing)

            Text(recorder.isSessionActive ? "Tap to Stop" : "Tap to Record")
                .font(narrow ? .caption2 : .caption)
                .multilineTextAlignment(.center)
                .lineLimit(narrow ? 2 : 1)
                .foregroundStyle(.secondary)
                .frame(height: narrow ? 30 : nil)
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
                    await transcribeAndSeparate(url: url)
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
