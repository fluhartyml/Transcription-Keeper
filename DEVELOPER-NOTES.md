# Transcription Keeper — developer notes

## 💡 2026-09-07 22:52 — HIS IDEA: put PTT into Transcription Keeper

> ***"we use it in transcription keeper make two branches to make transcription recordings"***

**Captured from bed, in his own words, so it is not lost.** Nothing has been built and **no branches
were created** — see the open question below.

### Where the idea came from, same evening
**PTT (push-to-talk) was built into Shell Citadel earlier tonight and it worked.** He liked it
immediately — *"the ptt was neat well have to make an app just fir it"* — but it shipped with the
glyph not actionable, the build went 92→93→95, **95 is broken, and PTT went to the wish list.**
**This is him finding it a real home instead.**

**And he had already named the use cases, unprompted:**
- *"maybe a transcription device for a stenographer or something"*
- *"just anytime maybe you are a secretary and you need to dictate your bosses notes"*
- *"i was interested in making a virtual stenographer machine"* · *"sounds like you need two iPhones
  or an iPad"* · an on-screen overlay, with **conductive pads and joysticks** as the input hardware

⭐ **Transcription Keeper is already live on the App Store (iOS 1.1).** So this is a feature on a
shipping app, not a new product — which makes the branch discipline below matter more, not less.

### He also named the interaction rule PTT needs, from hands-free
> *"It should say if I say never mind it should cancel"* · *"can the PTT have a pull mouse away
> cancel action equivilant?"*

**A push-to-talk with no cancel gesture is a push-to-talk that sends every misfire.** Whatever gets
built here needs the abort, not just the capture.

### ⬜ THE OPEN QUESTION — asked, not answered
**"Two branches" of WHAT?** Two competing PTT implementations to compare and keep the winner, or two
recording *modes* that both ship? **The answer changes what goes in each branch, and branch names
are his to give.** → [[feedback_no_impositions_no_implied_states]]

### State when this was captured
`main`, 8 commits, clean apart from an untracked `xcshareddata/`.

---

## 🎯 2026-09-08 — THE GOAL, CONFIRMED BY HIM. READ THIS BEFORE TOUCHING THE UI.

**This app is not a recorder with a toggle on it. It is a VIRTUAL STENOGRAPHER MACHINE —
an instrument someone operates without looking at it.**

Claude spent the afternoon patching a recording screen and he called it:
> ***"one flaw to fix tells me you dont understand the goal."***
Then, when the goal was said back to him: ***"exactly you did understand! BZ"***

### The two modes are two JOBS, not two settings
| Mode | What it is for |
|---|---|
| **Meeting** | Passive capture of a room. Set the squelch and let it run through a conversation. |
| **PTT** | **The operator decides what enters the record.** Nothing is kept unless a finger is down — and the abort means a misfire never enters it at all. |

**His labels, and they name the JOB rather than the mechanism** (2026-09-08: *"meeting and PTT"*).
Do not rename them to describe how they work.

### Where it is going — his words, captured 2026-09-07 and still the spec
- *"maybe a transcription device for a stenographer or something"*
- *"just anytime maybe you are a secretary and you need to dictate your bosses notes"*
- *"i was interested in making a virtual stenographer machine"*
- *"sounds like you need two iPhones or an iPad"* — **two devices, one instrument**
- **an on-screen overlay**, with **conductive pads and joysticks** as the input hardware
- *"It should say if I say never mind it should cancel"* — **the abort is load-bearing, not polish**

### ⚠️ What this means for whoever works on it next
**Judge every change against "can this be operated without looking at it?"** A control that needs
to be found on screen has already failed the machine, whatever it does once found. The conductive
pads and joysticks are the tell: the target is a physical instrument that happens to run on iOS.

**And do not report progress as a list of flaws fixed.** That framing is what he caught. The
question is never "what is broken" — it is "how much closer is this to something a stenographer
could actually sit down at."

---

## 🖨️ 2026-09-15 — PTT BECOMES A COMPOSING STICK. His design, worked out in conversation.

**He opened it the day 2.0 was approved:** *"wwe need to add features to the PTT."* And his verdict
on what shipped: ***"i just thing yje PTT as it is is too rudinentary."***

> ### 🔑 HIS METAPHOR IS THE SPEC — and it arrived late, after the mechanics
> ***"its like you type set each ptt as a line for an old printing press"***
>
> **A compositor sets a line of type, proofs it, and THEN places it in the galley.** Setting and
> placing are two separate physical acts, and a set line stays **movable** — pull it, re-place it,
> reorder it, without ever re-speaking it. **That is the whole architecture in one sentence**, and
> it is why the data model below is not negotiable: a burst has to be an OBJECT, not text appended
> to a blob. Text in a blob cannot be pulled back out and moved.

### ⛔ NOTHING COMMITS AT RELEASE — this is the correction he made to Claude's first sketch

***"shouldnt be pressured to make a descision the moment you press and release. maybe you press and
release say a sentence you see the transcript approve it for the paragraph, you press and release
but you see you said something erong you can edit add punctuation before you approve or
dissaprove."***

**A burst produces a PENDING chunk.** He reads it, edits it, adds punctuation, then approves or
discards. **Nothing enters the record on the release of the button.**

⚠️ **This deleted a control Claude had just proposed.** A "redo the last chunk" button was on the
table; **disapprove IS the redo**, and the extra button was solving a problem the staging step
removes. → [[feedback_design_it_right_first_not_patch_after]]

### 📐 THE LADDER — his words, and it is the same gesture four times

***"then after you see the block of text you approve for it to be a paragraph then you put together
the next paragraph then after msny paragraps you think a page is ready to go to press then you
publish"***

| Level | What accumulates | What ends it |
|---|---|---|
| **burst** | one press-and-release | he approves or discards the pending chunk |
| **paragraph** | approved chunks | he looks at the block and approves it as a paragraph |
| **page** | paragraphs | he decides it is ready to go to press |
| **document** | pages | **publish** |

**Accumulate → look → approve, at every level.** One UI pattern reused four times, not four
mechanisms. ⛔ **Nothing at any level commits on a timer, a pause, or a silence threshold.**

### 🎚️ SHORT BURSTS ARE THE UNIT — and it came from him failing at the app, not from theory

***"personally i had a tough time saying the second tongue twister"*** · ***"short bursts of ptt is
probably optimal."***

**Recording the 2.0 screenshots, he fumbled the tongue twister while holding the button.** Holding,
speaking, and getting it right at once is a real load. **Short bursts mean a fumble costs one press
instead of a paragraph** — the lived argument for the chunk model, and worth more than the
reasoning that reached the same place.

**Consequence, and it settled an open fork:** short bursts mean many presses per paragraph, so the
paragraph break **must be its own act**. ⛔ **"Mode-per-press" — where a setting declares each press
to be a sentence or a paragraph — is RULED OUT**; it would turn every burst into a paragraph. The
printing-press metaphor says the same thing independently: the line does not decide where it goes.

### 🗂️ TEMPLATES — what his three examples have in common

**His examples:** *"a report paper or some sort of non medical patient chart or even a book
report"* — ***"something you would need to press and release the ptt multiple times for the same
paragraph page or book of pages."***

⚠️ **NOTE THE QUALIFIER: "NON MEDICAL" IS HIS OWN WORD.** A patient chart shaped like a chart, with
no claim to be a medical device and no PHI handling promised. **Do not quietly upgrade it.**

**All three are an ordered list of named sections.** A chart: *Reason for visit / Observations /
Plan*. A book report: *Title / Summary / What I thought*. **Free-form paragraphs are that same list,
unnamed and open-ended** — so one mechanism covers every case. A template defines the slots, PTT
fills the current slot, and advancing moves to the next.

**That is also what his "tags" question resolves to:** the tags are the section names, supplied by
the template, and the screen can show which one he is currently talking into.

### ⬜ OPEN — not decided, do not assume either way

- **Does the review screen show the section name while he talks?** Asked, not yet answered.
- **⚠️ THE REAL TENSION, AND IT IS WITH THE 2026-09-08 GOAL ABOVE.** That entry says *"a control
  that needs to be found on screen has already failed the machine."* **This ladder is inherently
  eyes-on** — reading, editing and punctuating a chunk cannot be done without looking. **Claude's
  reading is that capture stays eyes-free and review is deliberately eyes-on, but HE HAS NOT RULED
  ON THAT** and it is not Claude's to decide. Raise it.
- **Versioning.** Claude observed once that this makes the app a composition tool that captures by
  voice, rather than a recorder with structure added. **Left entirely to him** — no version split
  was proposed. → [[feedback_no_preemptive_scope_cuts]]

### ⛔ REPO STATE WHEN THIS WAS WRITTEN — do not "tidy" it
`main` is at **20a5382, build 24**, which is the binary Apple approved at 01:48 today. **Two
modified files are the post-commit hook's stamp for that commit and are left uncommitted ON
PURPOSE** — committing them bumps the repo to build 25 and the shipped number stops matching.
**This notes file is likewise left uncommitted for now**, for the same reason.

### ✅ DECIDED 2026-09-15 — COMPOSE IS A THIRD TAB, not a setting inside PTT

**His call, in his own layout:** ***"recorder( meeting w squelch | PTT | Compose PTT)"***

**It earns a tab by the test already in this file: a tab is a JOB, not a setting.** Meeting and PTT
both produce **one transcript of one sitting**. Compose produces a **document**. Different artifact,
different job. ⛔ **Not a toggle buried inside PTT** — the capture gesture is the same in both, and
that similarity is exactly what would have made it look like a setting.

> ⛔ **THE NAME HERE IS SUPERSEDED — he renamed it "Composition" the same day. See the entry
> below.** The tab DECISION in this section stands; only the label changed.

**⚠️ "Compose PTT" is HIS name for it.** Same rule as Meeting and PTT: **the label names the job,
not the mechanism. Do not rename it** to describe how it works.

**⚠️ WHAT THE THIRD TAB DRAGS IN, and neither other tab has ever needed it:** Compose has **work in
progress that outlives the session.** A meeting ends. A book report is something he comes back to on
Thursday. **So Compose needs somewhere to RESUME from** — the first real persistence either of the
other two ever required. Flagged here, not designed; he has not ruled on it.

**Still uncommitted, same reason as the entry above:** `main` is at 20a5382 / build 24, the approved
binary, and the post-commit hook would bump it to 25.

---

## 📚 2026-09-15 (cont.) — "COMPOSITION": THE TAB IS A CONTAINER, NOT A CAPTURE MODE

### ⛔ THE CORRECTION THAT RESHAPED IT — and it supersedes "Compose PTT" above

***"maybe we have the third tab 'composition' and we figure a way to use either squelch recorder or
PTT but we need a way to signal the app were done with the first capture, link it to the next
capture and after making the chain of captures we compose or turn on the printing press and publish
the type set"***

**The tab is called Composition**, and it is **not a third way to capture.** It is a container that
**consumes** captures — **Meeting and PTT both feed it.** The earlier entry assumed PTT-only and was
wrong.

**⚠️ THE ONE CONTROL THAT DOES NOT EXIST IN EITHER MODE TODAY: "this capture is done."** PTT's
release cannot serve as it — **he already ruled that release does not commit.** Meeting has no end
signal at all except stopping. **That signal is the genuinely new piece; everything else is the
chain it builds.**

### 📄 A MEETING IS ONE PAGE — his ruling, and it plugs into the ladder

***"each meeting recorded would be one page in the report"***

**Asked whether a squelched meeting enters as one link or gets shattered into links by its own
silence gaps, he answered with the use case:** ***"well what if the user has a chain of meetings
they want in a report?"*** — **three chained meetings arriving as six hundred fragments is an
unusable report.** So the squelch segments live **inside** the page.

| Source | Enters the chain as | Gates it passes |
|---|---|---|
| **PTT burst** | a **line** — climbs line → paragraph → page | all three |
| **A whole meeting** | a **page**, already set | **page approval only** |

**So the chain holds MIXED SIZES.** A report is Monday's meeting + Wednesday's meeting + a few
paragraphs he dictates himself as the conclusions. ⚠️ **A meeting page skips two gates** — its only
look-before-it-commits is the page approval. **Same rule, one rung instead of three.**

### 🎬 HIS WORKED EXAMPLE — six pages, and read the fifth one carefully

> ***"the user uses the PTT to define the report book then the user uses the squelch recorder to
> record a meeting then the user uses the ptt to record their personal notes for the next page then
> the user uses the ptt to introduce the next meeting recorded the user uses the squelch recorder to
> record the meeting but decides to use only the audio and not the transcribed words, the user uses
> the ptt to set the next page with a summary of the previous meeting"***

| # | Source | Page |
|---|---|---|
| 1 | PTT | defines the report book |
| 2 | Meeting | the first meeting |
| 3 | PTT | his personal notes |
| 4 | PTT | introduces the next meeting |
| 5 | Meeting | **AUDIO ONLY — the transcript is deliberately discarded** |
| 6 | PTT | his summary of the previous meeting |

> ### 🔊 PAGE 5 IS THE ONE THAT CHANGES SOMETHING STRUCTURAL
> **A page can hold a recording that never becomes type** — and **he decides that AFTER recording,
> at the page gate.** Keep-the-audio / drop-the-transcript is a page-level choice made at the same
> approval every other page passes. **This is the first thing in the design that constrains the
> output format**, and it is what forced the publish question below.

**Also worth seeing in that list: FOUR of the six pages are HIM.** Define, notes, intro, summary —
authored — against two captured. **An authored page and a captured page probably should not look
alike when published.** ⬜ **Not ruled on.**

### 📦 PUBLISH PRODUCES A PACKAGE — his spec

***"publish can produce the contents in a package. if it is only transcribed text its a [PDF] if its
a mix then its a pdf split in multiplr filr names with the audio onlu having a file name that when
listed in a folder (or package) it is in the sequence 1 text pdf, 2 text pdf, 3 audio recording,
4 text pdf, 5 audio recording, 6 text pdf"***

- **Text only → one PDF.**
- **Mixed → ONE FILE PER PAGE**, numbered, audio interleaved by number.
- **The folder listing IS the binding.** Nothing proprietary: the package still reads correctly
  years from now with the app gone — the same instinct as keeping lines movable.

**✅ NUMBERING — his format: `001, 002, 003, 004, 005, 010, 015, 020`.**
- **Three digits, zero-padded.** ⛔ Unpadded, page 10 sorts ahead of page 2 and the sequence breaks
  at exactly the length where a report gets long enough to matter.
- **The gaps are insertion room** — a page can be dropped in later without renumbering the package.
  ⚠️ Claude asked whether the gaps were deliberate rather than assuming; **they are.** *(He framed
  the digit count as "just for the example" — the padding rule is settled, the exact width is not
  precious.)*

### 🔢 THE DOTTED ADDRESS — his idea, and Claude's counter-suggestion. NOT DECIDED.

**His idea:** ***"you can even use dots like ip addresses, one octet means sentence one octet means
paragraph another octet is page and another octet is volume, what you suggest"*** — and he also
raised that ***"maybe the numbering is realitive to the user,"*** per-sentence, per-line or per-page
as they choose.

**⚠️ WHAT FOLLOWS IS CLAUDE'S SUGGESTION, ASKED FOR BY NAME. HE HAS NOT RULED ON IT.**
→ [[feedback_dont_launder_your_own_suggestion_into_his_rule]]

**Suggested: keep the FILENAME flat, and give the dotted address a different job.**
1. **The package is a folder of PAGES.** Sentences and paragraphs never become files — they live
   inside the PDF — so two of four octets would be padding on every filename.
2. **The dotted address earns its keep as a CITATION**: "2.14.3" is something he can say out loud in
   a meeting and the app can jump to.
3. **The trap it avoids:** a name that encodes position must be rewritten whenever something moves,
   and a four-level name means rewriting everything beneath it too. **Identity stays put; position
   gets stamped only at publish.** That is the same reason the chunks are objects and not text.

### ⬜ STILL OPEN AFTER THIS SESSION
- ~~**Does review work blind?**~~ **ANSWERED — see "HYBRID ON PURPOSE" below. It is hybrid, and
  that is the design, not a gap.**
- **Where does Composition resume from?** It is the first mode with work that outlives the session.
- **Do authored pages and captured pages render differently?**
- **The dotted address** — citation, filename, or both.
- **Versioning.** No split was proposed and none should be. → [[feedback_no_preemptive_scope_cuts]]


### 🎧 HYBRID ON PURPOSE — his framing, and it corrects Claude's reading. 2026-09-15

**Claude over-ran this one.** Given his remark that Siri's no-screen shortfall is *"an engineering
choice because he assumes all iphone users are visual people, not thinking of the blind,"* Claude
pushed it to eyes-free operation and proposed reading every chunk back aloud so the gates could be
passed by ear. **He corrected it:**

> ***"i think you crossed two thoughts and made your commennt about needing visual and not speach
> only assumptions. i was thinking hybrid BUT Speach recognition with siri requires eyes and fingers
> because you have to loook to press the button and you have to see to proof the dictation"***

### 🔑 HIS ACTUAL POINT ABOUT SIRI — sharper than accessibility
**Siri dictation is SOLD as voice, and both ends of it are not.** You **look** to find the button,
and you **look** to proof the result. **Only the middle is voice.**

### ✅ SO THE RULING IS: HYBRID, DECLARED
**This app has the same shape — press, speak, read, approve — and that is FINE, because it is stated
rather than papered over.** **Hybrid on purpose instead of hybrid by omission.**

⛔ **DO NOT re-open this as "make the gates eyes-free."** The visual gates are the design. The
2026-09-08 *"operated without looking"* goal is about the **capture instrument**, not the proofing.

⚠️ **AND A SECOND CROSSED WIRE, named by him in the same breath:** some of his past *"speak to me"*
instructions were **about HIS setup, not about app design** — he could not see the external display
and was making Claude use the say tool. **Those are session-logistics remarks and must not be read
as requirements for Transcription Keeper.**
→ [[feedback_statements_not_directives]] · [[feedback_dont_launder_your_own_suggestion_into_his_rule]]

> ### 🧩 THE THIRD STRAND, NAMED BY HIM 2026-09-15 — and it belongs to a DIFFERENT APP
>
> ***"i recal i may have been mentioning the hands free for shell citadel because being completely
> hands free would make it a useful terminal app in the app store"***
>
> **Three separate things had been collapsed into one requirement for this app:**
>
> | Strand | What it actually is |
> |---|---|
> | Siri needs eyes and fingers at both ends | **His critique of Siri.** Informs the hybrid ruling above. |
> | *"speak to me"* | **His own setup** — he could not see the external display. Session logistics. |
> | **Fully hands-free** | **SHELL CITADEL's product argument**, not Transcription Keeper's. |
>
> ⛔ **So hands-free operation is NOT a Transcription Keeper requirement and never was.** The ruling
> above stands unchanged: **this app is hybrid on purpose** — press, speak, read, approve.
>
> ⚠️ **Do not carry the hands-free goal across from Shell Citadel.** Shell Citadel is his App-Store
> track and hands-free is the thing that would make a terminal app worth publishing; **this app has
> a different job.** → [[feedback_timer_module_decoupled_from_timermodules]] (same shape: two
> products, separate artifacts)


## ⬜ CONTACT THE DEVELOPER — NEXT UPDATE (his standard for all apps, 2026-09-18): the feedback form must send ONLY the user's message + the app version. Remove device model, OS, storage, locale and any other diagnostics. His words: "i dont want personal information. i just want a pipeline to communicate with users."
